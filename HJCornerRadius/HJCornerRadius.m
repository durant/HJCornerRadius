//
//  HJCornerRadius.m
//  HJImageViewDemo
//
//  Created by haijiao on 16/3/10.
//  Copyright © 2016年 olinone. All rights reserved.
//

#import "HJCornerRadius.h"
#import <objc/runtime.h>

@interface UIImage (cornerRadius)

@property (nonatomic, assign) BOOL aliCornerRadius;

@end

@implementation UIImage (cornerRadius)

- (BOOL)aliCornerRadius {
    return [objc_getAssociatedObject(self, @selector(aliCornerRadius)) boolValue];
}

- (void)setAliCornerRadius:(BOOL)aliCornerRadius {
    objc_setAssociatedObject(self, @selector(aliCornerRadius), @(aliCornerRadius), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

/////////////////////////////////////////////////////////////////////
@interface HJImageObserver : NSObject

@property (nonatomic, assign) UIImageView *originImageView;
@property (nonatomic, strong) UIImage *originImage;
@property (nonatomic, assign) CGFloat cornerRadius;

- (instancetype)initWithImageView:(UIImageView *)imageView;

@end

@implementation HJImageObserver

- (void)dealloc {
    [self.originImageView removeObserver:self forKeyPath:@"image"];
    [self.originImageView removeObserver:self forKeyPath:@"contentMode"];
}

- (instancetype)initWithImageView:(UIImageView *)imageView{
    if (self = [super init]) {
        self.originImageView = imageView;
        [imageView addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:nil];
        [imageView addObserver:self forKeyPath:@"contentMode" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString*, id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"image"]) {
        UIImage *newImage = change[@"new"];
        if (![newImage isKindOfClass:[UIImage class]] || newImage.aliCornerRadius) {
            return;
        }
        [self updateImageView];
    }
    if ([keyPath isEqualToString:@"contentMode"]) {
        self.originImageView.image = self.originImage;
    }
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    if (_cornerRadius == cornerRadius) {
        return;
    }
    _cornerRadius = cornerRadius;
    if (_cornerRadius > 0) {
        [self updateImageView];
    }
}

/*  modify by kevin
 *  @description 
 *      之前图片绘制是在main线程中进行的，现在改成在 子线程进行，使得程序运行流畅
 */

- (void)updateImageView {
    self.originImage = self.originImageView.image;
    if (!self.originImage) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        UIImage *image = nil;
        UIGraphicsBeginImageContextWithOptions(self.originImageView.bounds.size, NO, [UIScreen mainScreen].scale);
        CGContextRef currnetContext = UIGraphicsGetCurrentContext();
        if (currnetContext) {
            CGContextAddPath(currnetContext, [UIBezierPath bezierPathWithRoundedRect:self.originImageView.bounds cornerRadius:self.cornerRadius].CGPath);
            CGContextClip(currnetContext);
            [self.originImageView.layer renderInContext:currnetContext];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        
        if ([image isKindOfClass:[UIImage class]]) {
            image.aliCornerRadius = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.originImageView.image = image;
            });
        } else {
            [self updateImageView];
        }
    });
}

@end

/////////////////////////////////////////////////////////////////////
@implementation UIImageView (HJCornerRadius)

- (CGFloat)aliCornerRadius {
    return [self imageObserver].cornerRadius;
}

- (void)setAliCornerRadius:(CGFloat)aliCornerRadius {
    [self imageObserver].cornerRadius = aliCornerRadius;
}

- (HJImageObserver *)imageObserver {
    HJImageObserver *imageObserver = objc_getAssociatedObject(self, @selector(imageObserver));
    if (!imageObserver) {
        imageObserver = [[HJImageObserver alloc] initWithImageView:self];
        objc_setAssociatedObject(self, @selector(imageObserver), imageObserver, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageObserver;
}

@end
