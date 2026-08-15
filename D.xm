/**
 * WCPulseVideoDownload — 视频号下载
 * ============================================================================
 * 从 WCPulse.dylib 提取、并按微信头文件 dump(微信.h, 50704 个 .h)真实签名重新实现。
 *
 * 证据锚点(均来自真实头文件,非猜测):
 *  - 分享菜单  : WCFinderScrollActionSheet
 *        @property WCFinderFeedContentVM *contentVM;
 *        - (id)currentDisplayMediaInfo;            // 返回 WCFinderMediaInfo
 *  - feed 单元 : WCFinderShareFeedCellView
 *        @property (readonly) WCFinderShareFeedCellViewModel *viewModel;
 *        WCFinderShareFeedCellViewModel @property WCFinderDataItem *dataItem;
 *  - 数据对象  : WCFinderDataItem
 *        @property WCFinderMedia *media;
 *        - (id)mediaInfoForPlay;                   // 返回 WCFinderMediaInfo
 *        WCFinderMedia @property (readonly) WCFinderMediaInfo *currentMedia;
 *  - 视频地址  : WCFinderMediaInfo
 *        @property (copy, nonatomic) NSString *mediaURL;
 *        @property (retain, nonatomic) NSString *urlToken;
 *        @property (readonly, nonatomic) NSString *mediaUrlWithToken;   // WCPulse 实际使用的 selector
 *  - 落地相册  : PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:
 *  - 文件名模板: WCPulse_Finder_%@.mp4 (来自 WCPulse.dylib __cstring 0xac4a70)
 */

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

#pragma mark - 开关(对应 WCPulse 的 enableFinderVideoDownload / finderVideoAutoSaveToAlbum)

static BOOL WCPVD_enabled(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return [d objectForKey:@"wcpvd_enabled"] ? [d boolForKey:@"wcpvd_enabled"] : YES;
}
static BOOL WCPVD_autoSave(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"wcpvd_autoSave"];
}

#pragma mark - 从任意 feed 相关对象取视频地址(锚定 mediaUrlWithToken / mediaInfoForPlay)

static NSURL *WCPVD_videoURLFromObject(id obj) {
    if (!obj) return nil;
    __block NSURL *result = nil;
    // [A] 直接持有 WCFinderMediaInfo 的对象:优先用 mediaUrlWithToken(WCPulse 同款)
    NSArray<NSString *> *direct = @[@"currentDisplayMediaInfo", @"mediaInfoForPlay",
                                    @"currentMedia", @"media", @"mediaInfo"];
    for (NSString *s in direct) {
        SEL sel = NSSelectorFromString(s);
        if ([obj respondsToSelector:sel]) {
            id info = ((id(*)(id,SEL))objc_msgSend)(obj, sel);
            if (!info) continue;
            // info 可能是 WCFinderMediaInfo,或 WCFinderMedia(需再取 currentMedia)
            if ([info respondsToSelector:@selector(mediaUrlWithToken)]) {
                NSString *u = ((NSString *(*)(id,SEL))objc_msgSend)(info, @selector(mediaUrlWithToken));
                if (u.length) { result = [NSURL URLWithString:u]; break; }
            }
            if ([info respondsToSelector:@selector(mediaURL)]) {
                NSString *u = ((NSString *(*)(id,SEL))objc_msgSend)(info, @selector(mediaURL));
                if (u.length) { result = [NSURL URLWithString:u]; break; }
            }
            // 递归一层(WCFinderMedia -> currentMedia)
            if ([info respondsToSelector:@selector(currentMedia)]) {
                id mi = ((id(*)(id,SEL))objc_msgSend)(info, @selector(currentMedia));
                if ([mi respondsToSelector:@selector(mediaUrlWithToken)]) {
                    NSString *u = ((NSString *(*)(id,SEL))objc_msgSend)(mi, @selector(mediaUrlWithToken));
                    if (u.length) { result = [NSURL URLWithString:u]; break; }
                }
            }
        }
        if (result) break;
    }
    if (result) return result;

    // [B] 容器对象:沿 viewModel / dataItem / contentVM / media 递归一层
    for (NSString *k in @[@"viewModel", @"dataItem", @"contentVM", @"media", @"feedObject"]) {
        @try {
            id nested = [obj valueForKey:k];
            if (nested && nested != obj) {
                NSURL *u = WCPVD_videoURLFromObject(nested);
                if (u) return u;
            }
        } @catch (NSException *e) {}
    }
    return nil;
}

#pragma mark - 下载并保存到相册(锚定 creationRequestForAssetFromVideoAtFileURL:)

static void WCPVD_saveVideoToAlbum(NSURL *remoteURL, void(^done)(BOOL, NSString *)) {
    if (!remoteURL) { done(NO, @"无效视频地址"); return; }
    NSURLSession *session = [NSURLSession sharedSession];
    [[session downloadTaskWithURL:remoteURL completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err) {
        if (err || !loc) {
            dispatch_async(dispatch_get_main_queue(), ^{
                done(NO, [NSString stringWithFormat:@"下载失败:%@", err.localizedDescription]); });
            return;
        }
        NSString *name = [NSString stringWithFormat:@"WCPulse_Finder_%.0f.mp4",
                          [NSDate date].timeIntervalSince1970];
        NSURL *dest = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
        [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];
        NSError *mv = nil;
        [[NSFileManager defaultManager] moveItemAtURL:loc toURL:dest error:&mv];
        if (mv) { dispatch_async(dispatch_get_main_queue(), ^{ done(NO, @"保存临时文件失败"); }); return; }

        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus st) {
            if (st != PHAuthorizationStatusAuthorized) {
                [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ done(NO, @"未授权相册"); });
                return;
            }
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:dest];
            } completionHandler:^(BOOL ok, NSError *e2) {
                [[NSFileManager defaultManager] removeItemAtURL:dest error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    done(ok, ok ? @"已保存到相册" :
                         [NSString stringWithFormat:@"相册写入失败:%@", e2.localizedDescription]); });
            }];
        }];
    }] resume];
}

static void WCPVD_toast(NSString *msg) {
    UIWindow *win = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]])
            for (UIWindow *w in ((UIWindowScene *)s).windows) if (w.isKeyWindow) { win = w; break; }
    if (!win) win = UIApplication.sharedApplication.keyWindow;
    if (!win) return;
    UILabel *lb = [[UILabel alloc] init];
    lb.text = msg; lb.textColor = UIColor.whiteColor; lb.font = [UIFont systemFontOfSize:14];
    lb.backgroundColor = [UIColor colorWithWhite:0 alpha:0.82];
    lb.layer.cornerRadius = 8; lb.clipsToBounds = YES;
    [lb sizeToFit]; lb.frame = CGRectInset(lb.frame, 12, 8);
    lb.center = CGPointMake(win.bounds.size.width/2, win.bounds.size.height - 120);
    [win addSubview:lb];
    [UIView animateWithDuration:0.25 delay:1.6 options:0 animations:^{ lb.alpha = 0; }
        completion:^(BOOL f){ [lb removeFromSuperview]; }];
}

static void WCPVD_triggerFrom(id source) {
    if (!WCPVD_enabled()) return;
    NSURL *url = WCPVD_videoURLFromObject(source);
    if (!url) { WCPVD_toast(@"未能定位视频地址"); return; }
    WCPVD_toast(@"开始下载…");
    WCPVD_saveVideoToAlbum(url, ^(BOOL ok, NSString *m){ WCPVD_toast(m); });
}

#pragma mark - 入口 1(主):feed 单元注入可见「下载视频」按钮

%hook WCFinderShareFeedCellView

- (void)layoutSubviews {
    %orig;
    if (!WCPVD_enabled()) return;
    static char kBtn;
    if (objc_getAssociatedObject(self, &kBtn)) return;
    objc_setAssociatedObject(self, &kBtn, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"下载视频" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [btn setTitleColor:UIColor.systemBlueColor forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.92];
    btn.layer.cornerRadius = 14; btn.clipsToBounds = YES;
    CGFloat w = 64, h = 28;
    btn.frame = CGRectMake(self.bounds.size.width - w - 12,
                           self.bounds.size.height - h - 12, w, h);
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [btn addTarget:self action:@selector(wcpvd_downloadTapped)
          forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:btn];
}

%new
- (void)wcpvd_downloadTapped {
    // self.viewModel(WCFinderShareFeedCellViewModel) -> dataItem(WCFinderDataItem)
    //   -> mediaInfoForPlay -> WCFinderMediaInfo -> mediaUrlWithToken
    WCPVD_triggerFrom(self.viewModel ?: self);
}

%end

#pragma mark - 入口 2(分享菜单):WCFinderScrollActionSheet 追加下载项

%hook WCFinderScrollActionSheet

- (id)getRowItems:(unsigned long long)arg1 contentVM:(id)contentVM {
    id items = %orig;
    if (!WCPVD_enabled()) return items;

    // 每个 sheet 只注入一次(避免多行重复),挂在首个被构建的行上
    static char kInjected;
    if (objc_getAssociatedObject(self, &kInjected)) return items;
    objc_setAssociatedObject(self, &kInjected, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    Class itemCls = %c(WCFinderScrollActionSheetItem);
    if (!itemCls) return items;

    WCFinderScrollActionSheet *weakSelf = self;
    id item = [[itemCls alloc] init];
    if ([item respondsToSelector:@selector(setItemType:)]) {
        // 自定义 itemType(高位置 1,避免与系统 flag 冲突);网格图标可能回退为默认,
        // 但点击仍触发下载。可见且带文字的入口见上方 cell 按钮。
        [item setItemType:0x80000000 | 9527];
    }
    if ([item respondsToSelector:@selector(setSelection:)]) {
        [item setSelection:^{
            WCPVD_triggerFrom(weakSelf.contentVM ?: weakSelf);
        }];
    }
    NSMutableArray *arr = [items isKindOfClass:[NSArray class]] ? [items mutableCopy] : [NSMutableArray array];
    [arr addObject:item];
    return arr;
}

%end

%ctor { %init; }
