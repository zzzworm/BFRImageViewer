//
//  BFRImageContainerViewController.m
//  Buffer
//
//  Created by Jordan Morgan on 11/10/15.
//
//

#import "BFRImageContainerViewController.h"
#import "BFRBackLoadedImageSource.h"
#import "BFRImageViewerDownloadProgressView.h"
#import "BFRImageViewerConstants.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <SDWebImage/SDWebImage.h>


@interface BFRImageContainerViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate>

/*! This is responsible for panning and zooming the images. */
@property (strong, nonatomic, nonnull) UIScrollView *scrollView;

/*! The actual view which will display the @c UIImage, this is housed inside of the scrollView property. */
@property (strong, nonatomic, nullable) UIImageView *imgView;

/*! The actual view which will display the @c PHLivePhoto, this is housed inside of the scrollView property. */
@property (strong, nonatomic, nullable) PHLivePhotoView *livePhotoImgView;

/*! The actual view which will display the @c PHLivePhoto, this is housed inside of the scrollView property. */
@property (strong, nonatomic, nullable) SDAnimatedImageView *animatedImgView;

/*! The image created from the passed in imgSrc property. */
@property (strong, nonatomic, nullable) UIImage *imgLoaded;

/*! The live photo created from the passed in imgSrc property, if the asset's media subtype bitmask contains @t PHAssetMediaSubtypePhotoLive */
@property (strong, nonatomic, nullable) PHLivePhoto *liveImgLoaded;

/*! If the imgSrc property requires a network call, this displays inside the view to denote the loading progress. */
@property (strong, nonatomic, nullable) BFRImageViewerDownloadProgressView *progressView;

/*! The animator which attaches the behaviors needed to drag the image. */
@property (strong, nonatomic, nonnull) UIDynamicAnimator *animator;

/*! The behavior which allows for the image to "snap" back to the center if it's vertical offset isn't passed the closing points. */
@property (strong, nonatomic, nonnull) UIAttachmentBehavior *imgAttatchment;

/*! This view will either by a @c PINAnimatedImageView or an instance of @c PHLivePhotoView depending on the asset's type. */
@property (strong, nonatomic, readonly, nullable) __kindof UIView *activeAssetView;

/*! Currently, this only shows if a live photo is displayed to avoid gesture recognizer conflicts with playback and sharing. */
@property (strong, nonatomic, nullable) UIBarButtonItem *shareBarButtonItem;

@end

@implementation BFRImageContainerViewController

#pragma mark - Computed Property

- (__kindof UIView *)activeAssetView {
    switch (self.assetType) {
        case BFRImageAssetTypeLivePhoto:
            return self.livePhotoImgView;
            break;
        case BFRImageAssetTypeGIF:
            return self.animatedImgView;
            break;
        default:
            return self.imgView;
            break;
    }
    return (self.assetType == BFRImageAssetTypeLivePhoto) ? self.livePhotoImgView : self.imgView;
}

- (CGSize)activeAssetSize
{
    return (self.assetType == BFRImageAssetTypeLivePhoto) ? self.liveImgLoaded.size : self.imgLoaded.size;
}

#pragma mark - Lifecycle

// With peeking and popping, setting up your subviews in loadView will throw an exception
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // View setup
    self.view.backgroundColor = [UIColor clearColor];
    
    // Scrollview (for pinching in and out of image)
    self.scrollView = [self createScrollView];
    [self.view addSubview:self.scrollView];
    
    // Animator - used to snap the image back to the center when done dragging
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.scrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePop)
                                                 name:NOTE_VC_POPPED
                                               object:nil];
    
    // Fetch image - or just display it
    if ([self.imgSrc isKindOfClass:[NSURL class]]) {
        self.assetType = BFRImageAssetTypeRemoteImage;
        [self setProgressView];
        [self retrieveImageFromURL];
    } else if ([self.imgSrc isKindOfClass:[UIImage class]]) {
        self.assetType = BFRImageAssetTypeImage;
        self.imgLoaded = (UIImage *)self.imgSrc;
        [self addImageToScrollView];
    } else if ([self.imgSrc isKindOfClass:[PHAsset class]]) {
        PHAsset *assetSource = (PHAsset *)self.imgSrc;
        
        // Live photo, or regular
        if (assetSource.mediaSubtypes & PHAssetMediaSubtypePhotoLive) {
            self.assetType = BFRImageAssetTypeLivePhoto;
            [self setProgressView];
            [self retrieveLivePhotoFromAsset];
        } else {
            self.assetType = BFRImageAssetTypeImage;
            [self retrieveImageFromAsset];
        }
    } else if ([self.imgSrc isKindOfClass:[SDAnimatedImage class]]) {
        self.assetType = BFRImageAssetTypeGIF;
        [self retrieveImageFromSDAnimatedImage];
    } else if ([self.imgSrc isKindOfClass:[NSString class]]) {
        self.assetType = BFRImageAssetTypeRemoteImage;
        // Loading view
        NSURL *url = [NSURL URLWithString:self.imgSrc];
        self.imgSrc = url;
        [self setProgressView];
        [self retrieveImageFromURL];
    } else if ([self.imgSrc isKindOfClass:[BFRBackLoadedImageSource class]]) {
        self.assetType = BFRImageAssetTypeRemoteImage;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleHiResImageDownloaded:) name:NOTE_HI_RES_IMG_DOWNLOADED object:nil];
        self.imgLoaded = ((BFRBackLoadedImageSource *)self.imgSrc).image;
        [self addImageToScrollView];
    } else {
        self.assetType = BFRImageAssetTypeUnknown;
        [self showError];
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    // Scrollview
    [self.scrollView setFrame:self.view.bounds];
//    self.activeAssetView.frame = CGRectMake(self.activeAssetView.frame.origin.x, self.activeAssetView.frame.origin.y, self.view.bounds.size.width, self.view.bounds.size.height);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Methods

- (void)setProgressView {
    self.progressView = [BFRImageViewerDownloadProgressView new];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progressView];
    
    [NSLayoutConstraint activateConstraints:@[[self.progressView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
                                              [self.progressView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
                                              [self.progressView.widthAnchor constraintEqualToConstant:self.progressView.progessSize.width],
                                              [self.progressView.heightAnchor constraintEqualToConstant:self.progressView.progessSize.height]
                                              ]];
}

- (UIScrollView *)createScrollView {
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    sv.delegate = self;
    sv.showsHorizontalScrollIndicator = NO;
    sv.showsVerticalScrollIndicator = NO;
    sv.decelerationRate = UIScrollViewDecelerationRateFast;
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (@available(iOS 11.0, *)) {
        sv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    //For UI Toggling
    UITapGestureRecognizer *singleSVTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissUI)];
    singleSVTap.numberOfTapsRequired = 1;
    singleSVTap.cancelsTouchesInView = NO;
    [sv addGestureRecognizer:singleSVTap];
    
    return sv;
}

- (void)createActiveAssetView {
    [self.imgView removeFromSuperview];
    [self.livePhotoImgView removeFromSuperview];
    
    __kindof UIView *resizableImageView;
    
    if (self.assetType == BFRImageAssetTypeLivePhoto) {
        resizableImageView = [[PHLivePhotoView alloc] initWithFrame:CGRectMake(0, 0, self.imgLoaded.size.width, self.imgLoaded.size.height)];
        ((PHLivePhotoView *)resizableImageView).livePhoto = self.liveImgLoaded;
    } else if (self.assetType == BFRImageAssetTypeGIF) {
        resizableImageView = [[SDAnimatedImageView alloc] initWithImage:self.imgSrc];
    } else if (self.imgView == nil) {
        resizableImageView = [[UIImageView alloc] initWithImage:self.imgLoaded];
    }
    
    resizableImageView.frame = self.view.bounds;
    resizableImageView.clipsToBounds = YES;
    resizableImageView.contentMode = UIViewContentModeScaleAspectFit;
    resizableImageView.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
    resizableImageView.layer.cornerRadius = self.isBeingUsedFor3DTouch ? 14.0f : 0.0f;
    
    // Toggle UI controls
    UITapGestureRecognizer *singleImgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissUI)];
    singleImgTap.numberOfTapsRequired = 1;
    [resizableImageView setUserInteractionEnabled:YES];
    [resizableImageView addGestureRecognizer:singleImgTap];
    
    // Reset the image on double tap
    UITapGestureRecognizer *doubleImgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(recenterImageOriginOrZoomToPoint:)];
    doubleImgTap.numberOfTapsRequired = 2;
    [resizableImageView addGestureRecognizer:doubleImgTap];
    
    // Share options
    if (self.shouldDisableSharingLongPress == NO && (self.assetType != BFRImageAssetTypeLivePhoto)) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleShareLongPress:)];
        [resizableImageView addGestureRecognizer:longPress];
        [singleImgTap requireGestureRecognizerToFail:longPress];
    }
    
    // Ensure the single tap doesn't fire when a user attempts to double tap
    [singleImgTap requireGestureRecognizerToFail:doubleImgTap];
    
    // Dragging to dismiss
    UIPanGestureRecognizer *panImg = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    if (self.shouldDisableHorizontalDrag) {
        panImg.delegate = self;
    }
    [resizableImageView addGestureRecognizer:panImg];
    
    if (self.assetType == BFRImageAssetTypeLivePhoto) {
        self.livePhotoImgView = (PHLivePhotoView *)resizableImageView;
        
        if (self.shouldDisableAutoplayForLivePhoto == NO) {
            self.livePhotoImgView.playbackGestureRecognizer.enabled = NO;
        }
    } else {
        self.imgView = resizableImageView;
    }
}

- (void)addImageToScrollView {
    [self createActiveAssetView];
    [self.scrollView addSubview:self.activeAssetView];
    CGSize boundsSize = self.scrollView.bounds.size;
    [self setMaxMinZoomScalesForCurrentBounds:boundsSize];
    
    // Sizes
    CGSize imageSize = self.activeAssetSize;
    
    // Calculate Min
    CGFloat xScale =  imageSize.width / boundsSize.width ;
    CGFloat yScale =  imageSize.height / boundsSize.height;
    
    // Calculate Max
    CGFloat maxImageScale = MAX(xScale, yScale);
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        switch (self.contentMode) {
            case BFRImageContentModeOrigin:
                //[self.scrollView setZoomScale:maxImageScale animated:NO];
                //self.scrollView.contentOffset = CGPointZero;
                [self.scrollView setZoomScale:maxImageScale];
                [self.scrollView setContentOffset:CGPointZero animated:NO];
                break;
            case BFRImageContentModePreferFillWidth:
                if(xScale < yScale){
                    [self.scrollView setZoomScale:yScale/xScale animated:NO];
                    [self.scrollView setContentOffset:CGPointMake((yScale/xScale-1)/2*UIScreen.mainScreen.bounds.size.width, 0) animated:NO];
                }
                break;
            default:
                break;
        }
//    });

}

#pragma mark - Backloaded Image Notification

- (void)handleHiResImageDownloaded:(NSNotification *)note {
    id hiResResult = note.object;
    
    if ([hiResResult isKindOfClass:[UIImage class]]) {
        self.imgLoaded = hiResResult;
        self.imgView.image = self.imgLoaded;
    } else if ([hiResResult isKindOfClass:[SDAnimatedImage class]]) {
        self.assetType = BFRImageAssetTypeGIF;
        self.imgSrc = hiResResult;
        [self retrieveImageFromSDAnimatedImage];
    }
}

#pragma mark - orientation change

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [self setMaxMinZoomScalesForCurrentBounds:size];
}

#pragma mark - Gesture Recognizer Delegate

// If we have more than one image, this will cancel out dragging horizontally to make it easy to navigate between images
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.scrollView];
    return fabs(velocity.y) > fabs(velocity.x);
}

#pragma mark - Scrollview Delegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.scrollView.subviews.firstObject;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self.animator removeAllBehaviors];
    [self centerScrollViewContents];
}

#pragma mark - Scrollview Util Methods

/*! This calculates the correct zoom scale for the scrollview once we have the image's size */
- (void)setMaxMinZoomScalesForCurrentBounds:(CGSize)boundsSize {
    
    // Sizes
    CGSize imageSize = self.activeAssetSize;
    
    // Calculate Min
    CGFloat xScale =  imageSize.width / boundsSize.width ;
    CGFloat yScale =  imageSize.height / boundsSize.height;
    
    CGFloat minScale = MIN(MIN(xScale, yScale),1.0);
    
    // Calculate Max
    CGFloat maxImageScale = MAX(xScale, yScale);
    CGFloat maxScaleMainly = MAX(maxImageScale,1.0);
    
    CGFloat maxScale = maxScaleMainly;

    if (maxScale <= minScale) {
        maxScale = minScale * 2;
    }
    
    // Apply zoom
    self.scrollView.maximumZoomScale = maxScale;
    self.scrollView.minimumZoomScale = minScale;

}

/*! Called during zooming of the image to ensure it stays centered */
- (void)centerScrollViewContents {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect contentsFrame = self.activeAssetView.frame;
    
    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    } else {
        contentsFrame.origin.x = 0.0f;
    }
    
    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    } else {
        contentsFrame.origin.y = 0.0f;
    }
    
    self.activeAssetView.frame = contentsFrame;
}

/*! Called when an image is double tapped. Either zooms out or to specific point */
- (void)recenterImageOriginOrZoomToPoint:(UITapGestureRecognizer *)tap {
    if (self.scrollView.zoomScale == self.scrollView.maximumZoomScale) {
        // Zoom out since we zoomed in here
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    } else {
        //Zoom to a point
        CGPoint touchPoint = [tap locationInView:self.scrollView];
        [self.scrollView zoomToRect:CGRectMake(touchPoint.x, touchPoint.y, 1, 1) animated:YES];
    }
}


#pragma mark - Dragging and Long Press Methods
/*! This method has three different states due to the gesture recognizer. In them, we either add the required behaviors using UIDynamics, update the image's position based off of the touch points of the drag, or if it's ended we snap it back to the center or dismiss this view controller if the vertical offset meets the requirements. */
- (void)handleDrag:(UIPanGestureRecognizer *)recognizer {
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self.animator removeAllBehaviors];
        
        CGPoint location = [recognizer locationInView:self.scrollView];
        CGPoint imgLocation = [recognizer locationInView:self.activeAssetView];
        
        UIOffset centerOffset = UIOffsetMake(imgLocation.x - CGRectGetMidX(self.activeAssetView.bounds),
                                             imgLocation.y - CGRectGetMidY(self.activeAssetView.bounds));
        
        self.imgAttatchment = [[UIAttachmentBehavior alloc] initWithItem:self.activeAssetView offsetFromCenter:centerOffset attachedToAnchor:location];
        [self.animator addBehavior:self.imgAttatchment];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        [self.imgAttatchment setAnchorPoint:[recognizer locationInView:self.scrollView]];
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint location = [recognizer locationInView:self.scrollView];
        CGRect closeTopThreshhold = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height * .35);
        CGRect closeBottomThreshhold = CGRectMake(0, self.view.bounds.size.height - closeTopThreshhold.size.height, self.view.bounds.size.width, self.view.bounds.size.height * .35);
        
        // Check if we should close - or just snap back to the center
        if (CGRectContainsPoint(closeTopThreshhold, location) || CGRectContainsPoint(closeBottomThreshhold, location)) {
            [self.animator removeAllBehaviors];
            self.activeAssetView.userInteractionEnabled = NO;
            self.scrollView.userInteractionEnabled = NO;
            
            UIGravityBehavior *exitGravity = [[UIGravityBehavior alloc] initWithItems:@[self.activeAssetView]];
            if (CGRectContainsPoint(closeTopThreshhold, location)) {
                exitGravity.gravityDirection = CGVectorMake(0.0, -1.0);
            }
            exitGravity.magnitude = 15.0f;
            [self.animator addBehavior:exitGravity];
            
            [UIView animateWithDuration:0.25f animations:^ {
                self.activeAssetView.alpha = 0.25f;
            } completion:^ (BOOL done) {
                self.activeAssetView.alpha = 0.0f;
                [self dimissUIFromDraggingGesture];
            }];
            
        } else {
            [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
            UISnapBehavior *snapBack = [[UISnapBehavior alloc] initWithItem:self.activeAssetView snapToPoint:self.scrollView.center];
            [self.animator addBehavior:snapBack];
        }
    }
}

- (void)handleShareLongPress:(UILongPressGestureRecognizer *)longPress {
    if (longPress.state == UIGestureRecognizerStateBegan) {
        [self presentActivityController];
    }
}

- (void)presentActivityController {
    id activityItem = (self.assetType == BFRImageAssetTypeLivePhoto) ? self.liveImgLoaded : self.imgLoaded;
    if (activityItem == nil) return;
    
    UIActivityViewController *activityVC;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[activityItem] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
    } else {
        activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[activityItem] applicationActivities:nil];
        activityVC.modalPresentationStyle = UIModalPresentationPopover;
        activityVC.preferredContentSize = CGSizeMake(320,400);
        UIPopoverPresentationController *popoverVC = activityVC.popoverPresentationController;
        popoverVC.sourceView = self.activeAssetView;
        
        CGPoint touchPoint;
        if (self.assetType == BFRImageAssetTypeLivePhoto) {
            popoverVC.barButtonItem = self.shareBarButtonItem;
        } else {
            // Grab the long press
            UILongPressGestureRecognizer *longPress;
            for (UIGestureRecognizer *gesture in self.activeAssetView.gestureRecognizers) {
                if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
                    longPress = (UILongPressGestureRecognizer *)gesture;
                    break;
                }
            }
            
            touchPoint = [longPress locationInView:self.activeAssetView];
            popoverVC.sourceRect = CGRectMake(touchPoint.x, touchPoint.y, 1, 1);
        }
        
        [self presentViewController:activityVC animated:YES completion:nil];
    }
}

#pragma mark - Image Asset Retrieval

- (void)retrieveImageFromAsset {
    PHImageRequestOptions *reqOptions = [PHImageRequestOptions new];
    reqOptions.synchronous = YES;
    
    [[PHImageManager defaultManager] requestImageDataForAsset:self.imgSrc options:reqOptions resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
        self.imgLoaded = [UIImage imageWithData:imageData];
        [self addImageToScrollView];
    }];
}

- (void)retrieveLivePhotoFromAsset {
    PHLivePhotoRequestOptions *liveOptions = [PHLivePhotoRequestOptions new];
    liveOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    liveOptions.progressHandler = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = progress;
        });
    };
    
    PHAsset *asset = (PHAsset *)self.imgSrc;
    [[PHImageManager defaultManager] requestLivePhotoForAsset:(PHAsset *)self.imgSrc targetSize:CGSizeMake(asset.pixelWidth, asset.pixelHeight) contentMode:PHImageContentModeAspectFit options:liveOptions resultHandler:^(PHLivePhoto *livePhoto, NSDictionary *info) {
        [self.progressView removeFromSuperview];
        self.liveImgLoaded = livePhoto;
        [self addImageToScrollView];
        [self createLivePhotoChrome];
    }];
}

- (void)retrieveImageFromSDAnimatedImage {
    if (![self.imgSrc isKindOfClass:[SDAnimatedImage class]]) {
        return;
    }
    
    SDAnimatedImage *image = (SDAnimatedImage *)self.imgSrc;
    self.imgLoaded = image;
    
    [self addImageToScrollView];
}

- (void)retrieveImageFromURL {
    NSURL *url = (NSURL *)self.imgSrc;
    
    [[SDWebImageManager sharedManager] loadImageWithURL:url options:0 progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        float fractionCompleted = (float)receivedSize/(float)expectedSize;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = fractionCompleted;
        });
    } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !image) {
                [self.progressView removeFromSuperview];
                [self showError];
                return;
            }
            
            if([image isKindOfClass:SDAnimatedImage.class]){
                self.assetType = BFRImageAssetTypeGIF;
                self.imgSrc = image;
                [self retrieveImageFromSDAnimatedImage];
            } else {
                self.imgLoaded = image;
                [self addImageToScrollView];
            }
            
            [self.progressView removeFromSuperview];
        });
    }];
}

#pragma mark - Misc. Methods

// Creates the live photo badge and the share icon.
- (void)createLivePhotoChrome {
    UIImage *livePhotoBadge = [PHLivePhotoView livePhotoBadgeImageWithOptions:PHLivePhotoBadgeOptionsOverContent];
    UIBarButtonItem *livePhotoBarButton = [[UIBarButtonItem alloc] initWithImage:livePhotoBadge style:UIBarButtonItemStylePlain target:nil action:nil];
    
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    self.shareBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(presentActivityController)];
    
    UIToolbar *tb = [UIToolbar new];
    tb.tintColor = [UIColor whiteColor];
    [self.view addSubview:tb];
    tb.items = @[livePhotoBarButton, flexSpace, self.shareBarButtonItem];
    [tb setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [tb setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
    tb.translatesAutoresizingMaskIntoConstraints = NO;
    
    if (@available(iOS 11.0, *)) {
        [tb.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
        [tb.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor].active = YES;
        [tb.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor].active = YES;[tb.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
        [tb.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor].active = YES;
        [tb.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor].active = YES;
    } else {
        // Fallback on earlier versions
        [tb.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
        [tb.widthAnchor constraintEqualToAnchor:self.view.widthAnchor].active = YES;
        [tb.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;[tb.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
        [tb.widthAnchor constraintEqualToAnchor:self.view.widthAnchor].active = YES;
        [tb.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    }
    
}

- (void)dismissUI {
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTE_VC_SHOULD_DISMISS object:nil];
}

- (void)dimissUIFromDraggingGesture {
    // If we drag the image away to close things, don't do the custom dismissal transition
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTE_VC_SHOULD_DISMISS_FROM_DRAGGING object:nil];
}

- (void)showError {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:ERROR_TITLE message:ERROR_MESSAGE preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:GENERAL_OK style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTE_IMG_FAILED object:nil];
    }];
    [controller addAction:closeAction];
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)handlePop {
    self.activeAssetView.layer.cornerRadius = 0.0f;
}

@end
