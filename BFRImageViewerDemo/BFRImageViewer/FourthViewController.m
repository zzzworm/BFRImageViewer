//
//  FourthViewController.m
//  BFRImageViewer
//
//  Created by Jordan Morgan on 4/6/17.
//  Copyright © 2017 Andrew Yates. All rights reserved.
//

#import "FourthViewController.h"
#import "BFRBackLoadedImageSource.h"
#import "BFRImageViewController.h"

@interface FourthViewController ()

@end

@implementation FourthViewController

- (instancetype) init {
    if (self = [super init]) {
        self.title = @"Backloading";
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *openBigbtn = [UIButton buttonWithType:UIButtonTypeSystem];
    openBigbtn.translatesAutoresizingMaskIntoConstraints = NO;
    [openBigbtn addTarget:self action:@selector(openBigImage) forControlEvents:UIControlEventTouchUpInside];
    [openBigbtn setTitle:@"Open Big Image" forState:UIControlStateNormal];
    [openBigbtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.view addSubview:openBigbtn];
    [openBigbtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [openBigbtn.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-180].active = YES;
    
    UIButton *openLongbtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [openLongbtn addTarget:self action:@selector(openVeryLongImage) forControlEvents:UIControlEventTouchUpInside];
    openLongbtn.translatesAutoresizingMaskIntoConstraints = NO;
    [openLongbtn setTitle:@"Open very long Image" forState:UIControlStateNormal];
    [openLongbtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.view addSubview:openLongbtn];
    [openLongbtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [openLongbtn.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-140].active = YES;
    
    UIButton *openWidthbtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [openWidthbtn addTarget:self action:@selector(openVeryWidthImage) forControlEvents:UIControlEventTouchUpInside];
    openWidthbtn.translatesAutoresizingMaskIntoConstraints = NO;
    [openWidthbtn setTitle:@"Open very width Image" forState:UIControlStateNormal];
    [openWidthbtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.view addSubview:openWidthbtn];
    [openWidthbtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [openWidthbtn.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-100].active = YES;
    
    UIButton *openSmallbtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [openSmallbtn addTarget:self action:@selector(openSmallImage) forControlEvents:UIControlEventTouchUpInside];
    openSmallbtn.translatesAutoresizingMaskIntoConstraints = NO;
    [openSmallbtn setTitle:@"Open small Image" forState:UIControlStateNormal];
    [openSmallbtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [self.view addSubview:openSmallbtn];
    [openSmallbtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [openSmallbtn.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-60].active = YES;
    
    
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btn addTarget:self action:@selector(openImageViewer) forControlEvents:UIControlEventTouchUpInside];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:@"Backload URL Image" forState:UIControlStateNormal];
    [self.view addSubview:btn];
    [btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [btn.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20].active = YES;
    
    
    UIButton *btnClosure = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnClosure addTarget:self action:@selector(openImageViewerWithCompletionHandler) forControlEvents:UIControlEventTouchUpInside];
    btnClosure.translatesAutoresizingMaskIntoConstraints = NO;
    [btnClosure setTitle:@"Backload URL Image + Completion Handler" forState:UIControlStateNormal];
    [self.view addSubview:btnClosure];
    [btnClosure.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [btnClosure.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:20].active = YES;
}

- (void)openBigImage
{
    UIImage *image = [UIImage imageNamed:@"big"];
    BFRImageViewController *imageVC = [[BFRImageViewController alloc] initWithImageSource:@[image]];
    //imageVC.contentMode = BFRImageContentModeOrigin;
    [self presentViewController:imageVC animated:YES completion:nil];
}

- (void)openSmallImage
{
    UIImage *image = [UIImage imageNamed:@"cross"];
    BFRImageViewController *imageVC = [[BFRImageViewController alloc] initWithImageSource:@[image]];
    //imageVC.contentMode = BFRImageContentModePreferWidth;
    [self presentViewController:imageVC animated:YES completion:nil];
}

- (void)openVeryLongImage
{
    NSURL *fileUrl = [NSBundle.mainBundle URLForResource:@"higher" withExtension:@"JPG"];
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:fileUrl]];
    BFRImageViewController *imageVC = [[BFRImageViewController alloc] initWithImageSource:@[image]];
    //imageVC.contentMode = BFRImageContentModePreferWidth;
    [self presentViewController:imageVC animated:YES completion:nil];
}

- (void)openVeryWidthImage
{
    NSURL *fileUrl = [NSBundle.mainBundle URLForResource:@"widther" withExtension:@"JPG"];
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:fileUrl]];
    BFRImageViewController *imageVC = [[BFRImageViewController alloc] initWithImageSource:@[image]];
    [self presentViewController:imageVC animated:YES completion:nil];
}

- (void)openImageViewer {
    BFRBackLoadedImageSource *backloadedImage = [[BFRBackLoadedImageSource alloc] initWithInitialImage:[UIImage imageNamed:@"lowResImage"] hiResURL:[NSURL URLWithString:@"https://overflow.buffer.com/wp-content/uploads/2016/12/1-hByZ0VpJusdVwpZd-Z4-Zw.png"]];

    BFRImageViewController *imageVC = [[BFRImageViewController alloc] initWithImageSource:@[backloadedImage]];
    [self presentViewController:imageVC animated:YES completion:nil];
}

- (void)openImageViewerWithCompletionHandler {
    BFRBackLoadedImageSource *backloadedImage = [[BFRBackLoadedImageSource alloc] initWithInitialImage:[UIImage imageNamed:@"lowResImage"] hiResURL:[NSURL URLWithString:@"https://overflow.buffer.com/wp-content/uploads/2016/12/1-hByZ0VpJusdVwpZd-Z4-Zw.png"]];
    
    backloadedImage.onCompletion = ^(UIImage * _Nullable img, NSError * _Nullable error) {
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Download Done" message:[NSString stringWithFormat:@"Finished downloading hi res image.\nImage:%@\nError:%@", img, error] preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *close = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertVC addAction:close];
        

        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        
        [topController presentViewController:alertVC animated:YES completion:nil];
    };
    
    BFRImageViewController *imageVC = [[BFRImageViewController alloc] initWithImageSource:@[backloadedImage]];
    [self presentViewController:imageVC animated:YES completion:nil];
}

@end
