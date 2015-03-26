//
//  OAPOISearchViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 19/03/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAPOISearchViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "OsmAndApp.h"
#import "OAPOI.h"
#import "OAPOIType.h"
#import "OAPOICategory.h"
#import "OAPOIHelper.h"
#import "OAPointDescCell.h"
#import "OAIconTextTableViewCell.h"
#import "OASearchMoreCell.h"
#import "OAIconTextDescCell.h"
#import "OAAutoObserverProxy.h"

#import "OARootViewController.h"
#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OADefaultFavorite.h"
#import "OANativeUtilities.h"

#include <OsmAndCore.h>
#include <OsmAndCore/Utilities.h>

#define kMaxTypeRows 5
const static int kSearchRadiusKm[] = {1, 2, 5, 10, 20, 50, 100, 200, 500};

typedef enum
{
    EPOIScopeUndefined = 0,
    EPOIScopeCategory,
    EPOIScopeType,
    
} EPOIScope;

@interface OAPOISearchViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, OAPOISearchDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *topView;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;

@property (nonatomic) NSMutableArray* dataArray;
@property (nonatomic) NSMutableArray* dataArrayTemp;
@property (nonatomic) NSMutableArray* dataPoiArray;
@property (nonatomic) NSMutableArray* searchPoiArray;

@property (nonatomic) NSString* searchString;
@property (nonatomic) NSString* searchStringPrev;

@property (strong, nonatomic) OAAutoObserverProxy* locationServicesUpdateObserver;
@property CGFloat azimuthDirection;
@property NSTimeInterval lastUpdate;

@property (strong, nonatomic) dispatch_queue_t searchDispatchQueue;
@property (strong, nonatomic) dispatch_queue_t updateDispatchQueue;

@end

@implementation OAPOISearchViewController {
    
    BOOL isDecelerating;
    BOOL _isSearching;
    BOOL _poiInList;
    
    UIPanGestureRecognizer *_tblMove;
    
    UIImageView *_leftImgView;
    UIActivityIndicatorView *_activityIndicatorView;
    
    BOOL _needRestartSearch;
    BOOL _ignoreSearchResult;
    BOOL _increasingSearchRadius;
    BOOL _initData;
    BOOL _enteringCategoryOrType;
    
    int _searchRadiusIndex;
    int _searchRadiusIndexMax;
    
    EPOIScope _currentScope;
    NSString *_currentScopePoiTypeName;
    NSString *_currentScopePoiTypeNameLoc;
    NSString *_currentScopeCategoryName;
    NSString *_currentScopeCategoryNameLoc;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (dispatch_queue_t)searchDispatchQueue
{
    if (_searchDispatchQueue == nil) {
        _searchDispatchQueue = dispatch_queue_create("searchDispatchQueue", NULL);
    }
    return _searchDispatchQueue;
}

- (dispatch_queue_t)updateDispatchQueue
{
    if (_updateDispatchQueue == nil) {
        _updateDispatchQueue = dispatch_queue_create("updateDispatchQueue", NULL);
    }
    return _updateDispatchQueue;
}

- (void)commonInit
{
    _searchRadiusIndexMax = (sizeof kSearchRadiusKm) / (sizeof kSearchRadiusKm[0]) - 1;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tblMove = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                       action:@selector(moveGestureDetected:)];
    
    _textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(4.0, 0.0, 24.0, _textField.bounds.size.height)];
    _textField.leftViewMode = UITextFieldViewModeAlways;
    
    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:_textField.leftView.frame];
    _activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    
    _leftImgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"search_icon"]];
    _leftImgView.contentMode = UIViewContentModeCenter;
    _leftImgView.frame = _textField.leftView.frame;
    
    [_textField.leftView addSubview:_leftImgView];
    [_textField.leftView addSubview:_activityIndicatorView];
    
    [OAPOIHelper sharedInstance].delegate = self;
    
    [self showSearchIcon];
    [self generateData];
}

-(void)viewWillAppear:(BOOL)animated {
    
    [self setupView];
    
    OsmAndAppInstance app = [OsmAndApp instance];
    self.locationServicesUpdateObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                                    withHandler:@selector(updateDistanceAndDirection)
                                                                     andObserve:app.locationServices.updateObserver];
    
    [self registerForKeyboardNotifications];
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self showSearchIcon];
    [self.textField becomeFirstResponder];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.locationServicesUpdateObserver) {
        [self.locationServicesUpdateObserver detach];
        self.locationServicesUpdateObserver = nil;
    }
    
    [self unregisterKeyboardNotifications];
}

- (void)appplicationIsActive:(NSNotification *)notification {
    [self showSearchIcon];
}

-(void)showWaitingIndicator
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_leftImgView setHidden:YES];
        [_activityIndicatorView setHidden:NO];
        [_activityIndicatorView startAnimating];
    });
}

-(void)showSearchIcon
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_activityIndicatorView setHidden:YES];
        [_leftImgView setHidden:NO];
    });
}

-(void)moveGestureDetected:(id)sender
{
    [self.textField resignFirstResponder];
}

// keyboard notifications register+process
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

- (void)unregisterKeyboardNotifications
{
    //unregister the keyboard notifications while not visible
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    
}
// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillShow:(NSNotification*)aNotification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView addGestureRecognizer:_tblMove];
    });
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView removeGestureRecognizer:_tblMove];
    });
}


- (void)updateDistanceAndDirection
{
    if (!_poiInList)
        return;
    
    if ([[NSDate date] timeIntervalSince1970] - self.lastUpdate < 0.3 && !_initData)
        return;
    self.lastUpdate = [[NSDate date] timeIntervalSince1970];
    
    OsmAndAppInstance app = [OsmAndApp instance];
    // Obtain fresh location and heading
    CLLocation* newLocation = app.locationServices.lastKnownLocation;
    CLLocationDirection newHeading = app.locationServices.lastKnownHeading;
    CLLocationDirection newDirection =
    (newLocation.speed >= 1 /* 3.7 km/h */ && newLocation.course >= 0.0f)
    ? newLocation.course
    : newHeading;
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        [_dataPoiArray enumerateObjectsUsingBlock:^(id item, NSUInteger idx, BOOL *stop) {
            
            if ([item isKindOfClass:[OAPOI class]]) {
                
                OAPOI *itemData = item;
                
                const auto distance = OsmAnd::Utilities::distance(newLocation.coordinate.longitude,
                                                                  newLocation.coordinate.latitude,
                                                                  itemData.longitude, itemData.latitude);
                
                
                
                itemData.distance = [app getFormattedDistance:distance];
                itemData.distanceMeters = distance;
                CGFloat itemDirection = [app.locationServices radiusFromBearingToLocation:[[CLLocation alloc] initWithLatitude:itemData.latitude longitude:itemData.longitude]];
                itemData.direction = -(itemDirection + newDirection / 180.0f * M_PI);
            }
            
        }];
        
        if ([_dataPoiArray count] > 0) {
            NSArray *sortedArray = [_dataPoiArray sortedArrayUsingComparator:^NSComparisonResult(OAPOI *obj1, OAPOI *obj2)
                                    {
                                        double distance1 = obj1.distanceMeters;
                                        double distance2 = obj2.distanceMeters;
                                        
                                        return distance1 > distance2 ? NSOrderedDescending : distance1 < distance2 ? NSOrderedAscending : NSOrderedSame;
                                    }];
            [_dataPoiArray setArray:sortedArray];
        }
        
        if (isDecelerating)
            return;
        
        //[self refreshVisibleRows];
        [_tableView reloadData];
        if (_initData && _dataPoiArray.count > 0) {
            [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        }
        _initData = NO;
    });
}

- (void)refreshVisibleRows
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSArray *visibleIndexPaths = [self.tableView indexPathsForVisibleRows];
        [self.tableView reloadRowsAtIndexPaths:visibleIndexPaths withRowAnimation:UITableViewRowAnimationNone];
        
    });
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)generateData {
    
    if ([self acquireCurrentScope])
        return;
    
    _searchRadiusIndex = 0;
    
    if (self.searchString)
    {
        _ignoreSearchResult = NO;
        
        dispatch_async(self.updateDispatchQueue, ^{
    
            if ([self.searchString isEqualToString:self.searchStringPrev])
                return;
            else
                self.searchStringPrev = [_searchString copy];

            [self updateSearchResults];

            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self showWaitingIndicator];

                self.dataArray = [NSMutableArray arrayWithArray:self.dataArrayTemp];
                self.dataArrayTemp = nil;
                self.dataPoiArray = [NSMutableArray array];
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startCoreSearch) object:nil];
                [self performSelector:@selector(startCoreSearch) withObject:nil afterDelay:.4];
                
                [self refreshTable];
            });
        });
    }
    else
    {
        dispatch_async(self.updateDispatchQueue, ^{
            
            _ignoreSearchResult = YES;
            _poiInList = NO;
            self.searchStringPrev = nil;
            NSArray *sortedArrayItems = [[OAPOIHelper sharedInstance].poiCategories.allKeys sortedArrayUsingComparator:^NSComparisonResult(OAPOICategory* obj1, OAPOICategory* obj2) {
                return [obj1.nameLocalized localizedCaseInsensitiveCompare:obj2.nameLocalized];
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self showSearchIcon];
                self.dataArray = [NSMutableArray arrayWithArray:sortedArrayItems];
                self.dataPoiArray = [NSMutableArray array];
                [self refreshTable];
            });
        });
    }
    
}

-(void)refreshTable
{
    [_tableView reloadData];
    if (_dataArray.count > 0 || _dataPoiArray.count > 0)
        [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
}

-(void)setupView
{
}


#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataArray.count + _dataPoiArray.count + (_dataPoiArray.count > 0 && _currentScope != EPOIScopeUndefined && _searchRadiusIndex < _searchRadiusIndexMax ? 1 : 0);
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row >= _dataArray.count + _dataPoiArray.count) {
        OASearchMoreCell* cell;
        cell = (OASearchMoreCell *)[self.tableView dequeueReusableCellWithIdentifier:@"OASearchMoreCell"];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OASearchMoreCell" owner:self options:nil];
            cell = (OASearchMoreCell *)[nib objectAtIndex:0];
        }
        if (_searchRadiusIndex < _searchRadiusIndexMax)
        {
            cell.textView.text = [NSString stringWithFormat:@"Increase search radius to %@", [[OsmAndApp instance] getFormattedDistance:kSearchRadiusKm[_searchRadiusIndex + 1] * 1000.0]];
        }
        else
        {
            cell.textView.text = @"Maximum search radius reached";
        }
        return cell;
    }
    
    id obj;
    if (indexPath.row >= _dataArray.count)
        obj = _dataPoiArray[indexPath.row - _dataArray.count];
    else
        obj = _dataArray[indexPath.row];
    
    
    if ([obj isKindOfClass:[OAPOI class]]) {
        
        static NSString* const reusableIdentifierPoint = @"OAPointDescCell";
        
        OAPointDescCell* cell;
        cell = (OAPointDescCell *)[self.tableView dequeueReusableCellWithIdentifier:reusableIdentifierPoint];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OAPointDescCell" owner:self options:nil];
            cell = (OAPointDescCell *)[nib objectAtIndex:0];
        }
        
        if (cell) {
            
            OAPOI* item = obj;
            [cell.titleView setText:item.nameLocalized];
            cell.titleIcon.image = [item icon];
            [cell.descView setText:item.type.nameLocalized];
            
            [cell.distanceView setText:item.distance];
            cell.directionImageView.transform = CGAffineTransformMakeRotation(item.direction);
        }
        
        return cell;
        
    } else if ([obj isKindOfClass:[OAPOIType class]]) {
        
        OAIconTextDescCell* cell;
        cell = (OAIconTextDescCell *)[self.tableView dequeueReusableCellWithIdentifier:@"OAIconTextDescCell"];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OAIconTextDescCell" owner:self options:nil];
            cell = (OAIconTextDescCell *)[nib objectAtIndex:0];
            cell.iconView.contentMode = UIViewContentModeScaleAspectFit;
            cell.iconView.frame = CGRectMake(12.5, 12.5, 25.0, 25.0);
        }
        
        if (cell) {
            OAPOIType* item = obj;
            
            [cell.textView setText:item.nameLocalized];
            [cell.descView setText:item.categoryLocalized];
            [cell.iconView setImage: [item icon]];
        }
        return cell;
        
    } else if ([obj isKindOfClass:[OAPOICategory class]]) {
        
        OAIconTextTableViewCell* cell;
        cell = (OAIconTextTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:@"OAIconTextTableViewCell"];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OAIconTextCell" owner:self options:nil];
            cell = (OAIconTextTableViewCell *)[nib objectAtIndex:0];
            cell.iconView.contentMode = UIViewContentModeScaleAspectFit;
            cell.iconView.frame = CGRectMake(12.5, 12.5, 25.0, 25.0);
        }
        
        if (cell) {
            OAPOICategory* item = obj;
            
            [cell.textView setText:item.nameLocalized];
            [cell.iconView setImage: [item icon]];
        }
        return cell;
        
    } else {
        return nil;
    }
    
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    isDecelerating = YES;
}

// Load images for all onscreen rows when scrolling is finished
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        isDecelerating = NO;
        [self refreshVisibleRows];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    isDecelerating = NO;
    [self refreshVisibleRows];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (indexPath.row >= _dataArray.count + _dataPoiArray.count)
    {
        if (_searchRadiusIndex < _searchRadiusIndexMax)
        {
            _searchRadiusIndex++;
            _ignoreSearchResult = NO;
            _increasingSearchRadius = YES;
            dispatch_async(dispatch_get_main_queue(), ^
                           {
                               [self startCoreSearch];
                           });
        }
        return;
    }
    
    id obj;
    if (indexPath.row >= _dataArray.count)
        obj = _dataPoiArray[indexPath.row - _dataArray.count];
    else
        obj = _dataArray[indexPath.row];
    
    if ([obj isKindOfClass:[OAPOI class]]) {
        OAPOI* item = obj;
        NSString *name = item.nameLocalized;
        if (!name)
            name = item.type.nameLocalized;
        [self goToPoint:item.latitude longitude:item.longitude name:item.nameLocalized];
        
    } else if ([obj isKindOfClass:[OAPOIType class]]) {
        OAPOIType* item = obj;
        self.searchString = [item.nameLocalized stringByAppendingString:@" "];
        _enteringCategoryOrType = YES;
        [self updateTextField:self.searchString];
        
    } else if ([obj isKindOfClass:[OAPOICategory class]]) {
        OAPOICategory* item = obj;
        self.searchString = [item.nameLocalized stringByAppendingString:@" "];
        _enteringCategoryOrType = YES;
        [self updateTextField:self.searchString];
    }
}

-(void)updateTextField:(NSString *)text
{
    NSString *t = (text ? text : @"");
    _textField.text = t;
    [self generateData];
}

-(NSString *)firstToken:(NSString *)text
{
    if (!text || text.length == 0)
        return nil;
    
    if (_enteringCategoryOrType)
    {
        _enteringCategoryOrType = NO;
        return text;
    }
    
    if (_currentScope != EPOIScopeUndefined)
    {
        NSString *currentScopeNameLoc = (_currentScope == EPOIScopeCategory ? _currentScopeCategoryNameLoc : _currentScopePoiTypeNameLoc);
        if ([self beginWith:currentScopeNameLoc text:text] && (text.length == currentScopeNameLoc.length || [text characterAtIndex:currentScopeNameLoc.length] == ' '))
        {
            if (text.length > currentScopeNameLoc.length)
            {
                return [text substringToIndex:currentScopeNameLoc.length + 1];
            }
            else
            {
                return text;
            }
        }
    }
    
    NSRange r = [text rangeOfString:@" "];
    if (r.length == 0)
        return text;
    else
        return [text substringToIndex:r.location + 1];
    
}

-(NSString *)nextTokens:(NSString *)text
{
    if (!text || text.length == 0)
        return nil;
    
    if (_currentScope != EPOIScopeUndefined)
    {
        NSString *currentScopeNameLoc = (_currentScope == EPOIScopeCategory ? _currentScopeCategoryNameLoc : _currentScopePoiTypeNameLoc);
        if ([self beginWith:currentScopeNameLoc text:text])
        {
            if (text.length > currentScopeNameLoc.length + 1)
            {
                NSString *res = [text substringFromIndex:currentScopeNameLoc.length + 1];
                return res.length == 0 ? nil : res;
            }
            else
            {
                return nil;
            }
        }
    }
    
    NSRange r = [text rangeOfString:@" "];
    if (r.length == 0)
        return nil;
    else if (text.length > r.location + 1)
        return [text substringFromIndex:r.location + 1];
    else
        return nil;
}

-(BOOL)acquireCurrentScope
{
    NSString *firstToken = [self firstToken:self.searchString];
    if (!firstToken)
    {
        _currentScope = EPOIScopeUndefined;
        return NO;
    }
    
    
    BOOL trailingSpace = [[firstToken substringFromIndex:firstToken.length - 1] isEqualToString:@" "];
    
    NSString *nextStr = [[self nextTokens:self.searchString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *currentScopeNameLoc = (_currentScope == EPOIScopeCategory ? _currentScopeCategoryNameLoc : _currentScopePoiTypeNameLoc);
    
    if (_currentScope != EPOIScopeUndefined && [firstToken isEqualToString:(trailingSpace ? [currentScopeNameLoc stringByAppendingString:@" "] : currentScopeNameLoc)]) {
        
        if (_currentScope == EPOIScopeCategory && nextStr) {
            NSArray* searchableContent = [OAPOIHelper sharedInstance].poiTypes;
            for (OAPOIType *poi in searchableContent) {
                
                if ([nextStr localizedCaseInsensitiveCompare:poi.nameLocalized] == NSOrderedSame &&
                    [_currentScopeCategoryName isEqualToString:poi.category])
                {
                    _currentScope = EPOIScopeType;
                    _currentScopePoiTypeName = poi.name;
                    _currentScopePoiTypeNameLoc = poi.nameLocalized;
                    _currentScopeCategoryName = poi.category;
                    _currentScopeCategoryNameLoc = poi.categoryLocalized;
                    
                    self.searchString = [_currentScopePoiTypeNameLoc stringByAppendingString:(trailingSpace ? @" " : @"")];
                    [self updateTextField:self.searchString];
                    return YES;
                }
            }
        }
        return NO;
    }
    
    EPOIScope prevScope = _currentScope;
    NSString *prevScopeTypeName = _currentScopePoiTypeName;
    NSString *prevScopeTypeNameLoc = _currentScopePoiTypeNameLoc;
    NSString *prevScopeCategoryName = _currentScopeCategoryName;
    NSString *prevScopeCategoryNameLoc = _currentScopeCategoryNameLoc;
    
    BOOL found = NO;
    
    NSString *str = [firstToken stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray* searchableContent = [OAPOIHelper sharedInstance].poiTypes;
    for (OAPOIType *poi in searchableContent)
    {
        if ([str localizedCaseInsensitiveCompare:poi.nameLocalized] == NSOrderedSame)
        {
            found = YES;
            _currentScope = EPOIScopeType;
            _currentScopePoiTypeName = poi.name;
            _currentScopePoiTypeNameLoc = poi.nameLocalized;
            _currentScopeCategoryName = poi.category;
            _currentScopeCategoryNameLoc = poi.categoryLocalized;
            
            break;
        }
        else if ([str localizedCaseInsensitiveCompare:poi.categoryLocalized] == NSOrderedSame)
        {
            found = YES;
            _currentScope = EPOIScopeCategory;
            _currentScopePoiTypeName = nil;
            _currentScopePoiTypeNameLoc = nil;
            _currentScopeCategoryName = poi.category;
            _currentScopeCategoryNameLoc = poi.categoryLocalized;
            
            break;
        }
    }
    
    if (found)
    {
        if (prevScope != _currentScope ||
            ![prevScopeTypeName isEqualToString:_currentScopePoiTypeName] ||
            ![prevScopeTypeNameLoc isEqualToString:_currentScopePoiTypeNameLoc] ||
            ![prevScopeCategoryName isEqualToString:_currentScopeCategoryName] ||
            ![prevScopeCategoryNameLoc isEqualToString:_currentScopeCategoryNameLoc])
        {
            NSString *currentScopeNameLoc = (_currentScope == EPOIScopeCategory ? _currentScopeCategoryNameLoc : _currentScopePoiTypeNameLoc);
            self.searchString = [currentScopeNameLoc stringByAppendingString:(trailingSpace ? @" " : @"")];
            [self updateTextField:self.searchString];
            return YES;
        }
    }
    else
    {
        _currentScope = EPOIScopeUndefined;
        _currentScopePoiTypeName = nil;
        _currentScopePoiTypeNameLoc = nil;
        _currentScopeCategoryName = nil;
        _currentScopeCategoryNameLoc = nil;
    }
    
    return NO;
}

- (void)updateSearchResults
{
    [self performSearch:_searchString];
}

- (void)performSearch:(NSString*)searchString
{
    self.dataArrayTemp = [NSMutableArray array];
    
    // If case searchString is empty, there are no results
    if (searchString == nil || [searchString length] == 0)
        return;
    
    // In case searchString has only spaces, also nothing to do here
    if ([[searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0)
        return;
    
    // Select where to look
    NSArray* searchableContent = [OAPOIHelper sharedInstance].poiTypes;
    
    NSComparator typeComparator = ^NSComparisonResult(id obj1, id obj2)
    {
        OAPOIType *item1 = obj1;
        OAPOIType *item2 = obj2;
        
        return [item1.nameLocalized localizedCaseInsensitiveCompare:item2.nameLocalized];
    };
    
    NSString *str = searchString;
    if (_currentScope != EPOIScopeUndefined)
        str = [[self nextTokens:str] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (_currentScope == EPOIScopeUndefined)
    {
        NSArray *sortedCategories = [[OAPOIHelper sharedInstance].poiCategories.allKeys sortedArrayUsingComparator:^NSComparisonResult(OAPOICategory* obj1, OAPOICategory* obj2) {
            return [obj1.nameLocalized localizedCaseInsensitiveCompare:obj2.nameLocalized];
        }];
        
        for (OAPOICategory *c in sortedCategories)
            if ([self beginWithOrAfterSpace:str text:c.nameLocalized])
                [_dataArrayTemp addObject:c];
        
    }
    
    if (_currentScope != EPOIScopeType)
    {
        NSMutableArray *typesStrictArray = [NSMutableArray array];
        NSMutableArray *typesOthersArray = [NSMutableArray array];
        for (OAPOIType *poi in searchableContent) {
            
            if (_currentScopeCategoryName && ![poi.category isEqualToString:_currentScopeCategoryName])
                continue;
            if (_currentScopePoiTypeName && ![poi.name isEqualToString:_currentScopePoiTypeName])
                continue;
            
            if (!str)
            {
                if (poi.filter)
                {
                    // todo make filter object later
                    [typesOthersArray addObject:poi];
                }
                else
                {
                    [typesOthersArray addObject:poi];
                }
            }
            else if ([self beginWithOrAfterSpace:str text:poi.nameLocalized])
            {
                if ([self containsWord:str inText:poi.nameLocalized])
                    [typesStrictArray addObject:poi];
                else
                    [typesOthersArray addObject:poi];
            }
            else if ([self beginWithOrAfterSpace:str text:poi.filter])
            {
                [typesOthersArray addObject:poi];
            }
        }
        
        if (!str)
        {
            [typesOthersArray sortUsingComparator:typeComparator];
            self.dataArrayTemp = [[_dataArrayTemp arrayByAddingObjectsFromArray:typesOthersArray] mutableCopy];
        }
        else
        {
            [typesStrictArray sortUsingComparator:typeComparator];
            
            int rowsForOthers = kMaxTypeRows - (int)typesStrictArray.count;
            if (rowsForOthers > 0)
            {
                [typesOthersArray sortUsingComparator:typeComparator];
                if (typesOthersArray.count > rowsForOthers)
                    [typesOthersArray removeObjectsInRange:NSMakeRange(rowsForOthers, typesOthersArray.count - rowsForOthers)];
                
                typesStrictArray = [[typesStrictArray arrayByAddingObjectsFromArray:typesOthersArray] mutableCopy];
            }
            
            self.dataArrayTemp = [[_dataArrayTemp arrayByAddingObjectsFromArray:typesStrictArray] mutableCopy];
        }
    }
}

- (BOOL)containsWord:(NSString *)str inText:(NSString *)text
{
    NSString *src = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *tokens = [text componentsSeparatedByString:@" "];
    
    for (NSString *t in tokens)
        if ([t localizedCaseInsensitiveCompare:src] == NSOrderedSame)
            return YES;
    
    return NO;
}

- (BOOL)beginWithOrAfterSpace:(NSString *)str text:(NSString *)text
{
    return [self beginWith:str text:text] || [self beginWithAfterSpace:str text:text];
}

- (BOOL)beginWith:(NSString *)str text:(NSString *)text
{
    return [[text lowercaseStringWithLocale:[NSLocale currentLocale]] hasPrefix:[str lowercaseStringWithLocale:[NSLocale currentLocale]]];
}

- (BOOL)beginWithAfterSpace:(NSString *)str text:(NSString *)text
{
    NSRange r = [text rangeOfString:@" "];
    if (r.length == 0 || r.location + 1 >= text.length)
        return NO;
    
    NSString *s = [text substringFromIndex:r.location + 1];
    return [[s lowercaseStringWithLocale:[NSLocale currentLocale]] hasPrefix:[str lowercaseStringWithLocale:[NSLocale currentLocale]]];
}

- (IBAction)btnCancelClicked:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)textFieldValueChanged:(id)sender
{
    if (_textField.text.length > 0)
        self.searchString = _textField.text;
    else
        self.searchString = nil;
    
    [self generateData];
}

- (void)goToPoint:(double)latitude longitude:(double)longitude name:(NSString *)name
{
    OARootViewController* rootViewController = [OARootViewController instance];
    [rootViewController closeMenuAndPanelsAnimated:YES];
    
    const OsmAnd::LatLon latLon(latitude, longitude);
    OAMapViewController* mapVC = [OARootViewController instance].mapPanel.mapViewController;
    OAMapRendererView* mapRendererView = (OAMapRendererView*)mapVC.view;
    Point31 pos = [OANativeUtilities convertFromPointI:OsmAnd::Utilities::convertLatLonTo31(latLon)];
    [mapVC goToPosition:pos andZoom:kDefaultFavoriteZoom animated:YES];
    [mapVC showContextPinMarker:latitude longitude:longitude];
    
    CGPoint touchPoint = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
    touchPoint.x *= mapRendererView.contentScaleFactor;
    touchPoint.y *= mapRendererView.contentScaleFactor;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSetTargetPoint
                                                        object: self
                                                      userInfo:@{@"caption" : name,
                                                                 @"lat": [NSNumber numberWithDouble:latLon.latitude],
                                                                 @"lon": [NSNumber numberWithDouble:latLon.longitude],
                                                                 @"touchPoint.x": [NSNumber numberWithFloat:touchPoint.x],
                                                                 @"touchPoint.y": [NSNumber numberWithFloat:touchPoint.y]}];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)sender
{
    return YES;
}

-(void)startCoreSearch
{
    _needRestartSearch = YES;
    
    if (![[OAPOIHelper sharedInstance] breakSearch])
        _needRestartSearch = NO;
    else
        return;
    
    
    dispatch_async(self.searchDispatchQueue, ^{
    
        if (_ignoreSearchResult) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showSearchIcon];
            });
            _poiInList = NO;
            return;
        }
        
        self.searchPoiArray = [NSMutableArray array];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWaitingIndicator];
        });
        
        OAPOIHelper *poiHelper = [OAPOIHelper sharedInstance];
        
        OAMapViewController* mapVC = [OARootViewController instance].mapPanel.mapViewController;
        OAMapRendererView* mapRendererView = (OAMapRendererView*)mapVC.view;
        [poiHelper setVisibleScreenDimensions:[mapRendererView getVisibleBBox31] zoomLevel:mapRendererView.zoomLevel];
        CLLocation* newLocation = [OsmAndApp instance].locationServices.lastKnownLocation;
        poiHelper.myLocation = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon(newLocation.coordinate.latitude, newLocation.coordinate.longitude));
        
        if (_currentScope == EPOIScopeUndefined)
            [poiHelper findPOIsByKeyword:self.searchString];
        else
            [poiHelper findPOIsByKeyword:self.searchString categoryName:_currentScopeCategoryName poiTypeName:_currentScopePoiTypeName radiusMeters:kSearchRadiusKm[_searchRadiusIndex] * 1200.0];
    });
}

#pragma mark - OAPOISearchDelegate

-(void)poiFound:(OAPOI *)poi
{
    if (_currentScope != EPOIScopeUndefined)
    {
        NSString *nextStr = [[self nextTokens:self.searchString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (nextStr.length == 0 || [self beginWith:nextStr text:poi.nameLocalized])
            [_searchPoiArray addObject:poi];
    }
    else
    {
        [_searchPoiArray addObject:poi];
    }
}

-(void)searchDone:(BOOL)wasInterrupted
{
    if (!wasInterrupted && !_needRestartSearch)
    {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSearchIcon];
        });
        
        if (_ignoreSearchResult)
        {
            _poiInList = NO;
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            _poiInList = _searchPoiArray.count > 0;
            
            self.dataPoiArray = [NSMutableArray arrayWithArray:self.searchPoiArray];
            self.searchPoiArray = nil;
            
            if (_poiInList)
            {
                _initData = !_increasingSearchRadius;
                [self updateDistanceAndDirection];
                _increasingSearchRadius = NO;
            }
            else
            {
                [_tableView reloadData];
            }
            
        });
        
        
    }
    else if (_needRestartSearch)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startCoreSearch];
        });
    }
}

@end