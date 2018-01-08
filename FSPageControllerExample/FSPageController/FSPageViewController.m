//
//  FSPageViewController.m
//  FSPageControllerExample
//
//  Created by vcyber on 2018/1/3.
//  Copyright © 2018年 vcyber. All rights reserved.
//

#import "FSPageViewController.h"
#import "FSHeaderLabel.h"
#import "UIView+FSFrame.h"


#define FSDefaultTitleMargin 20
#define FSDefaultFont [UIFont systemFontOfSize:15]
#define FSBaseTag 20000

#define FSScreenW [UIScreen mainScreen].bounds.size.width
#define FSScreenH [UIScreen mainScreen].bounds.size.height

@interface FSPageViewController ()<UIScrollViewDelegate, FSHeaderLabelDelegate> {
    BOOL _isAppear;
    BOOL _dragging;

}

@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UIScrollView *titleContentView;
@property (nonatomic, strong) NSMutableArray<FSHeaderLabel *> *titleLabels;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *titleWidths;

@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) NSMutableArray<NSValue *> *vcViewFrames;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIViewController *> *displayVCCache;

@property (nonatomic, assign) CGFloat lastContentOffsetX;

@end

@implementation FSPageViewController

//MARK: - 声明周期

- (instancetype)init
{
    return [self initWithClassNames:nil titles:nil];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self initial];
}

- (void)initial {
    _titleHeight = 44;
}

- (instancetype)initWithClassNames:(NSArray<Class> *)classes titles:(NSArray<NSString *> *)titles {
    self = [super init];
    if (self) {
        _vcClasses = [classes copy];
        _titles = [titles copy];
        [self initial];
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
//    防止带有tabBarController和NaviagtionController组合时候的偏移
    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.vcClasses.count == 0) {
        return;
    }
//    if (!_isAppear) {
        [self fs_forceLayout];
        _isAppear = YES;
//    }
}

- (void)fs_forceLayout {
    [self fs_calculateFrames];
    [self fs_setUpTitles];
    self.selectedIndex = self.selectedIndex;
}

// MARK: - Private Method
- (void)fs_calculateFrames {
    NSUInteger vcCount = self.vcClasses.count;
    
    
    if (vcCount != self.titles.count) {
        NSException *e = [NSException exceptionWithName:@"FSPageContrller" reason:@"子控制器和标题数量不相等" userInfo:nil];
        [e raise];
    }
    
    CGFloat titleY = [[UIApplication sharedApplication] statusBarFrame].size.height;
    if (self.navigationController && !self.navigationController.navigationBarHidden) {
        titleY += self.navigationController.navigationBar.fs_height;
    }
    
    self.contentView.frame = CGRectMake(0, 0, FSScreenW, FSScreenH);
    
    self.titleContentView.frame = CGRectMake(0, titleY, FSScreenW, _titleHeight);
    
    CGFloat contentScrollViewHeight = self.contentView.fs_height - self.titleContentView.fs_y - self.titleContentView.fs_height;
    if (!self.tabBarController.tabBar.hidden) {
        contentScrollViewHeight -= self.tabBarController.tabBar.fs_height;
    }
    self.contentScrollView.frame = CGRectMake(0, self.titleContentView.fs_y + self.titleContentView.fs_height, self.contentView.fs_width, contentScrollViewHeight);
    self.contentScrollView.contentSize = CGSizeMake(self.contentScrollView.fs_width * self.childControllerCount, self.contentScrollView.fs_height);
    
    [self.titleWidths removeAllObjects];
    CGFloat totalWidth = 0;
    for (NSString *title in self.titles) {
        if ([title isKindOfClass:[NSString class]]) {
            CGRect titleBounds = [title boundingRectWithSize:CGSizeMake(MAXFLOAT, 0) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: self.titleFont} context:nil];
            [self.titleWidths addObject:@(titleBounds.size.width)];
            totalWidth += titleBounds.size.width;
        }
    }
    
    [self.vcViewFrames removeAllObjects];
    for (int i = 0; i < self.childControllerCount; i++) {
        CGRect frame = CGRectMake(i * self.contentScrollView.fs_width, 0, self.contentScrollView.fs_width, self.contentScrollView.fs_height);
        [self.vcViewFrames addObject:[NSValue valueWithCGRect:frame]];
    }
    
    if (totalWidth > FSScreenW || self.titleMargin != FSDefaultTitleMargin) {
        self.titleContentView.contentInset = UIEdgeInsetsMake(0, 0, 0, self.titleMargin);
        return;
    }
    
    CGFloat titleMargin = (FSScreenW - totalWidth) / (vcCount + 1);
    self.titleMargin = titleMargin > FSDefaultTitleMargin ? titleMargin : FSDefaultTitleMargin;
    self.titleContentView.contentInset = UIEdgeInsetsMake(0, 0, 0, self.titleMargin);

}


- (void)fs_setUpTitles {
    NSUInteger count = self.titles.count;
    
    for (UILabel *label in self.titleLabels) {
        [label removeFromSuperview];
    }
    [self.titleLabels removeAllObjects];
    
    CGFloat titleLabelW, titleLabelH, titleLabelX, titleLabelY;
    titleLabelH = _titleHeight;
    
    for (int i = 0; i < count; i++) {
        FSHeaderLabel *lastLabel = [self.titleLabels lastObject];
        titleLabelW = [self.titleWidths[i] floatValue];
        titleLabelX = lastLabel.fs_x + lastLabel.fs_width + self.titleMargin;
        titleLabelY = 0;
        FSHeaderLabel *currentLabel = [[FSHeaderLabel alloc] initWithFrame:CGRectMake(titleLabelX, titleLabelY, titleLabelW, titleLabelH)];
        currentLabel.text = self.titles[i];
        currentLabel.font = self.titleFont;
        currentLabel.normalColor = self.titleNormalColor;
        currentLabel.selectedColor = self.titleSelectedColor;
        currentLabel.tag = FSBaseTag + i;
        currentLabel.delegate = self;
        [self.titleLabels addObject:currentLabel];
        [self.titleContentView addSubview:currentLabel];
    }
    FSHeaderLabel *lastLabel = [self.titleLabels lastObject];
    self.titleContentView.contentSize = CGSizeMake(lastLabel.fs_x + lastLabel.fs_width, _titleHeight);
}

- (UIViewController *)fs_initViewControllerWithIndex:(NSUInteger)index {
    UIViewController *vc = [self.displayVCCache objectForKey:@(index)];

    if (!vc) {
        vc = [[self.vcClasses[index] alloc] init];
        vc.title = self.titles[index];
        [self.displayVCCache setObject:vc forKey:@(index)];
    }
    vc.view.frame = [self.vcViewFrames[index] CGRectValue];
    return vc;
}

- (void)fs_addChildViewControllerAtIndex:(NSUInteger)index {
    UIViewController *vc = [self fs_initViewControllerWithIndex:index];
    [vc didMoveToParentViewController:self];
    [self fs_addViewAtIndex:index];
}

- (void)fs_addViewAtIndex:(NSUInteger)index {
    UIViewController *vc = [self fs_initViewControllerWithIndex:index];
    if (vc.view.superview) {
        return;
    }
    [self.contentScrollView addSubview:vc.view];
}


- (void)fs_addViewOrViewControllerAtIndex:(NSUInteger)index {
    if (!self.displayVCCache[@(index)]) {
        [self fs_addChildViewControllerAtIndex:index];
    }else {
        [self fs_addViewAtIndex:index];
    }
}

- (void)fs_removeViewAtIndex:(NSUInteger)index {
    if (!self.displayVCCache[@(index)]) {
        return;
    }
    UIViewController *vc = [self fs_initViewControllerWithIndex:index];
    if (vc.view.superview) {
        [vc.view removeFromSuperview];
    }
}

- (void)fs_changeTitleWithIndex:(NSUInteger)selectedIndex {
    FSHeaderLabel *lastLabel = self.titleLabels[_selectedIndex];
    lastLabel.normalColor = self.titleNormalColor;
    lastLabel.selectedColor = self.titleSelectedColor;
    FSHeaderLabel *selectedLabel = self.titleLabels[selectedIndex];
    selectedLabel.normalColor = self.titleSelectedColor;
    selectedLabel.selectedColor = self.titleNormalColor;
}


// MARK: - Setter & Getter
- (UIFont *)titleFont {
    if (!_titleFont) {
        _titleFont = FSDefaultFont;
    }
    return _titleFont;
}

- (UIColor *)titleNormalColor {
    if (!_titleNormalColor) {
        _titleNormalColor = [UIColor blackColor];
    }
    return _titleNormalColor;
}

- (UIColor *)titleSelectedColor {
    if (!_titleSelectedColor) {
        _titleSelectedColor = [UIColor redColor];
    }
    return _titleSelectedColor;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    if (self.titleLabels.count) {
        [self fs_changeTitleWithIndex:selectedIndex];
        if (selectedIndex != 0) {
            [self.contentScrollView setContentOffset:CGPointMake(selectedIndex * self.contentScrollView.fs_width, 0)];
        }else if (selectedIndex == 0) {
            [self fs_addChildViewControllerAtIndex:selectedIndex];
        }
    }
         _selectedIndex = selectedIndex;
}


- (CGFloat)titleMargin {
    if (_titleMargin == 0) {
        return FSDefaultTitleMargin;
    }
    return _titleMargin;
}

// MARK: - 懒加载

- (UIView *)contentView {
    if (!_contentView) {
        _contentView = [UIView new];
        [self.view addSubview:_contentView];
    }
    return _contentView;
}

- (UIScrollView *)titleContentView {
    if (!_titleContentView) {
        _titleContentView = [[UIScrollView alloc] init];
        if (@available(iOS 11.0, *)) {
            _titleContentView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            // Fallback on earlier versions
        }
        _titleContentView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
        _titleContentView.showsVerticalScrollIndicator = NO;
        _titleContentView.showsHorizontalScrollIndicator = NO;
        [self.contentView addSubview:_titleContentView];
    }
    return _titleContentView;
}

- (NSMutableArray<FSHeaderLabel *> *)titleLabels {
    if (!_titleLabels) {
        _titleLabels = [NSMutableArray array];
    }
    return _titleLabels;
}

- (NSMutableArray<NSNumber *> *)titleWidths {
    if (!_titleWidths) {
        _titleWidths = [NSMutableArray array];
    }
    return _titleWidths;
}

- (UIScrollView *)contentScrollView {
    if (!_contentScrollView) {
        _contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _contentScrollView.showsVerticalScrollIndicator = NO;
        _contentScrollView.showsHorizontalScrollIndicator = NO;
        _contentScrollView.delegate = self;
        _contentScrollView.bounces = NO;
        _contentScrollView.pagingEnabled = YES;
        if (@available(iOS 11.0, *)) {
            _contentScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            // Fallback on earlier versions
        }
        [self.contentView addSubview:_contentScrollView];
    }
    return _contentScrollView;
}

- (NSMutableDictionary<NSNumber *,UIViewController *> *)displayVCCache {
    if (!_displayVCCache) {
        _displayVCCache = [NSMutableDictionary dictionary];
    }
    return _displayVCCache;
}


- (NSMutableArray<NSValue *> *)vcViewFrames {
    if (!_vcViewFrames) {
        _vcViewFrames = [NSMutableArray array];
    }
    return _vcViewFrames;
}

- (NSUInteger)childControllerCount {
    return self.vcClasses.count;
}

// MARK: - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offsetX = scrollView.contentOffset.x;
    NSUInteger index = (NSUInteger)(offsetX / scrollView.fs_width);
    
    if (!_dragging) {
        [self fs_addViewOrViewControllerAtIndex:index];
        return;
    }

    if (self.lastContentOffsetX > offsetX) {  //右划index-1
//        针对左滑松手后反弹之后，因为左滑之后左滑index不变，移除刚刚显示的view就是移除index + 1的view，这里需要判断极限offset
        if (offsetX == index * scrollView.fs_width) {
            [self fs_removeViewAtIndex:(index + 1)];
            return;
        }
//            右划需要移除上次显示在中间的View的index+1的view  又因为右划index会-1，所以这里应该使用index+2
        if (self.displayVCCache[@(index + 2)] && self.displayVCCache[@(index + 2)].view.superview) {
            [self fs_removeViewAtIndex:index + 2];
        }

    }else { //左滑index不变
//        针对右滑松手后反弹之后
        if (offsetX == index * scrollView.fs_width) {
            [self fs_removeViewAtIndex:index - 1];
            return;
        }
//        左滑需要移除上次显示在中间View的index-1的View，因为左滑index不变，所以直接移除index-1的view即可
        if (self.displayVCCache[@(index - 1)] && self.displayVCCache[@(index -1)].view.superview) {
            [self.displayVCCache[@(index - 1)].view removeFromSuperview];
        }
        
//        因为需要展示下一个vc，所以需要index+1，然后展示
        index += 1;
        if (index >= self.childControllerCount) {
            return;
        }
    }
    
//    显示vc
    [self fs_addViewOrViewControllerAtIndex:index];
    
    _lastContentOffsetX = offsetX;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    _dragging = YES;
}


- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat offsetX = scrollView.contentOffset.x;
    NSUInteger index = (NSUInteger)(offsetX / scrollView.fs_width);
    _dragging = NO;
    [self fs_changeTitleWithIndex:index];
    _selectedIndex = index;
}

// MARK: -FSHeaderLabelDelegate
- (void)touchUpInside:(FSHeaderLabel *)headerLabel {
    NSInteger index = headerLabel.tag - FSBaseTag;
    if (index == self.selectedIndex) {
        return;
    }
    [self fs_removeViewAtIndex:self.selectedIndex];
    [self fs_changeTitleWithIndex:index];
    [self fs_addViewOrViewControllerAtIndex:index];
    [self.contentScrollView setContentOffset:CGPointMake(index * self.contentScrollView.fs_width, 0)];
    _selectedIndex = index;
}

// MARK: --
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dealloc {
    
}

@end
