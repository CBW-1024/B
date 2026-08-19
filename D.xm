// DD图片表情增强 —— 长按图片消息转表情、长按表情消息保存到图库
// 版本 1.2.0
//
// 菜单注入严格对齐 WCP 逆向结论（见 /workspace/WCPulse_Reversed/out/HOOKS.md 与 dylib 反汇编）：
//   ✅ WCP hook 的是  BaseMessageCellView -filteredMenuItems:  （不是 MMMenuController）
//   ✅ 取图         WCP 先 StartDownloadImage:HD:... 下载高清，再 processImageData: 处理
//   ✅ 转表情       WCP processImageData: 用 UIImage 缩放后调用
//                   CEmoticonMgr +emoticonMsgForImageData:errorMsg: 生成表情消息并发送（直接发送）
//   ✅ 保存         WCP onSaveEmoticonToAlbum: 取 m_nsEmoticonMD5 → pathOfEmoticonForMd5: 拿原文件 →
//                   读 data → 若为 wxam 用 createGifFromWxAMData: 转 GIF → PHPhotoLibrary 存相册
//   ✅ 图标         微信内置 SVG：initWithTitle:svgName:target:action:
//
// 本插件据此实现，并加入调试日志（设置页可查看 / 导出 / 清空），便于真机定位。
//
// v1.2.0 变更（针对「日志为空 + 无按钮」）：
//   - 多入口 Hook：同时 hook BaseMessageCellView -filteredMenuItems:（WCP 路径）、
//     ImageMessageCellView -operationMenuItems:、EmoticonMessageCellView -operationMenuItems:，
//     保证图片/表情长按菜单无论走哪个入口都能命中。
//   - 日志增强：%ctor 强制同步写启动日志到 微信 Documents/DDImageEmoji_log.txt（文件管理器可见），
//     可直接判断 tweak 是否加载、哪个菜单入口被调用。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Photos/Photos.h>

// MARK: - 微信私有接口声明（仅声明用到的部分，缺方法则用 performSelector 兜底）

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsEmoticonMD5;
- (BOOL)IsImgMsg;
@end

@interface BaseMessageViewModel : NSObject
@property(retain, nonatomic) CMessageWrap *messageWrap;
@end

@interface BaseMessageCellView : UIView
@property(readonly, nonatomic) BaseMessageViewModel *viewModel;
- (id)filteredMenuItems:(id)items;
- (id)operationMenuItems;
@end

// 图片/表情 cell（继承 BaseMessageCellView，各自 override 了 operationMenuItems:）
@interface ImageMessageCellView : BaseMessageCellView
@end
@interface EmoticonMessageCellView : BaseMessageCellView
@end

@interface MMMenuItem : UIMenuItem
@property(nonatomic, weak) id target;
@property(nonatomic) SEL action;
@property(retain, nonatomic) UIImage *iconImage;
- (id)initWithTitle:(NSString *)title svgName:(NSString *)svgName target:(id)target action:(SEL)action;
- (id)initWithTitle:(NSString *)title svgName:(NSString *)svgName action:(SEL)action;
- (id)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
- (id)initWithTitle:(NSString *)title target:(id)target action:(SEL)action;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)serviceClass;
@end

@interface CEmoticonMgr : NSObject
// 类方法
+ (id)getEmoticonImageByMD5:(NSString *)md5;
+ (id)emoticonMsgForImageData:(NSData *)data errorMsg:(id *)errorMsg;
// 实例方法（用于取原文件路径、转 GIF、加表情面板等，按 WCP 调用）
- (id)pathOfEmoticonForMd5:(NSString *)md5 needUpdateTime:(BOOL)need ignoreWxAM:(BOOL)ignore;
- (id)createGifFromWxAMData:(NSData *)data;
- (id)AddCustomEmoticonWithData:(NSData *)data addEmoticonWrap:(id)wrap isSilently:(BOOL)silently;
@end

@interface AddEmoticonWrap : NSObject
- (id)initWithMessageWrap:(CMessageWrap *)wrap AndSource:(int)source;
@end

@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
- (void)StartDownloadImage:(id)arg1 HD:(BOOL)arg2 AutoDownload:(BOOL)arg3 SaveAlbum:(BOOL)arg4 Silent:(BOOL)arg5 behavior:(long long)arg6;
@end

// MARK: - 调试日志（内存环形缓冲 + 文件落盘）

// 落盘路径：临时目录 + 微信 Documents 各一份（Documents 用文件管理器必能看到）
#define DD_LOG_FILE_TMP [NSTemporaryDirectory() stringByAppendingPathComponent:@"DDImageEmoji.log"]

// 取 Documents 下的日志路径（带缓存，避免每次求值）
static NSString *DDLogDocPath(void) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *p = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path = p.count ? [p[0] stringByAppendingPathComponent:@"DDImageEmoji_log.txt"]
                       : DD_LOG_FILE_TMP;
    });
    return path;
}

@interface DDImageEmojiLog : NSObject
@property(nonatomic, strong) NSMutableArray<NSString *> *lines;
+ (instancetype)shared;
- (void)append:(NSString *)fmt, ...;
- (void)appendSync:(NSString *)line;   // 同步写入内存 + 落盘（%ctor 早期用，确保可读）
- (NSString *)allText;
- (void)clear;
@end

@implementation DDImageEmojiLog
+ (instancetype)shared {
    static DDImageEmojiLog *l = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ l = [self new]; });
    return l;
}
- (instancetype)init {
    if (self = [super init]) {
        _lines = [NSMutableArray array];
        // 启动时把已有日志文件读回内存（便于跨次查看）
        @try {
            NSString *old = [NSString stringWithContentsOfFile:DD_LOG_FILE_TMP
                                                       encoding:NSUTF8StringEncoding error:nil];
            if (!old.length) {
                old = [NSString stringWithContentsOfFile:DDLogDocPath()
                                                encoding:NSUTF8StringEncoding error:nil];
            }
            if (old.length) [_lines addObjectsFromArray:[old componentsSeparatedByString:@"\n"]];
            if (_lines.count > 800) [_lines removeObjectsInRange:NSMakeRange(0, _lines.count - 800)];
        } @catch (NSException *e) {}
    }
    return self;
}
- (NSString *)timestampedLine:(NSString *)msg {
    @try {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss.SSS";
        return [NSString stringWithFormat:@"[%@] %@", [df stringFromDate:[NSDate date]], msg];
    } @catch (NSException *e) { return msg; }
}
- (void)writeAll {
    @try {
        NSString *text = [_lines componentsJoinedByString:@"\n"];
        [text writeToFile:DD_LOG_FILE_TMP atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [text writeToFile:DDLogDocPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } @catch (NSException *e) {}
}
- (void)append:(NSString *)fmt, ... {
    @try {
        va_list ap; va_start(ap, fmt);
        NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);
        NSString *line = [self timestampedLine:msg];
        [_lines addObject:line];
        if (_lines.count > 800) [_lines removeObjectAtIndex:0];
        // 异步落盘，避免阻塞主线程
        NSString *snapshot = [_lines copy];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            @try {
                NSString *text = [snapshot componentsJoinedByString:@"\n"];
                [text writeToFile:DD_LOG_FILE_TMP atomically:YES encoding:NSUTF8StringEncoding error:nil];
                [text writeToFile:DDLogDocPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
            } @catch (NSException *e) {}
        });
    } @catch (NSException *e) {}
}
- (void)appendSync:(NSString *)line {
    @try {
        [_lines addObject:[self timestampedLine:line]];
        if (_lines.count > 800) [_lines removeObjectAtIndex:0];
        [self writeAll];
    } @catch (NSException *e) {}
}
- (NSString *)allText {
    return [_lines componentsJoinedByString:@"\n"];
}
- (void)clear {
    [_lines removeAllObjects];
    @try {
        [[NSFileManager defaultManager] removeItemAtPath:DD_LOG_FILE_TMP error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:DDLogDocPath() error:nil];
    } @catch (NSException *e) {}
}
@end

#define DDLog(fmt, ...) [[DDImageEmojiLog shared] append:fmt, ##__VA_ARGS__]

// MARK: - 配置

static NSString * const kDDImageEmojiConfigKey = @"DDImageEmojiConfig";
static NSString * const kDDImageEmojiEnableSaveEmoticonToAlbum = @"enableSaveEmoticonToAlbum";
static NSString * const kDDImageEmojiEnableImageToEmoticon = @"enableImageToEmoticon";
static NSString * const kDDImageEmojiEnableImageToEmoticonDirectSend = @"enableImageToEmoticonDirectSend";

@interface DDImageEmojiConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)isEnabled;
- (BOOL)enableSaveEmoticonToAlbum;
- (BOOL)enableImageToEmoticon;
- (BOOL)enableImageToEmoticonDirectSend;
@end

@implementation DDImageEmojiConfig
+ (instancetype)shared {
    static DDImageEmojiConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDImageEmojiConfig new]; });
    return cfg;
}
- (NSDictionary *)config {
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:kDDImageEmojiConfigKey];
    if ([obj isKindOfClass:[NSDictionary class]]) return obj;
    // 首次启动默认开启两个主功能，直接发送默认关闭（对齐 WCP：默认就给按钮）
    return @{
        kDDImageEmojiEnableSaveEmoticonToAlbum: @(YES),
        kDDImageEmojiEnableImageToEmoticon: @(YES),
        kDDImageEmojiEnableImageToEmoticonDirectSend: @(NO),
    };
}
- (void)setValue:(id)value forConfigKey:(NSString *)key {
    NSMutableDictionary *cfg = [[self config] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (value) [cfg setValue:value forKey:key];
    else       [cfg removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDImageEmojiConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (BOOL)isEnabled { return self.enableSaveEmoticonToAlbum || self.enableImageToEmoticon; }
- (BOOL)enableSaveEmoticonToAlbum {
    NSNumber *v = [self.config objectForKey:kDDImageEmojiEnableSaveEmoticonToAlbum];
    return v ? v.boolValue : NO;
}
- (BOOL)enableImageToEmoticon {
    NSNumber *v = [self.config objectForKey:kDDImageEmojiEnableImageToEmoticon];
    return v ? v.boolValue : NO;
}
- (BOOL)enableImageToEmoticonDirectSend {
    NSNumber *v = [self.config objectForKey:kDDImageEmojiEnableImageToEmoticonDirectSend];
    return v ? v.boolValue : NO;
}
@end

// MARK: - 工具函数

static id ddGetService(NSString *className) {
    if (!className.length) return nil;
    Class cls = NSClassFromString(className);
    if (!cls) return nil;
    Class centerCls = NSClassFromString(@"MMServiceCenter");
    if (!centerCls || ![centerCls respondsToSelector:@selector(defaultCenter)]) return nil;
    id center = [centerCls defaultCenter];
    if (!center || ![center respondsToSelector:@selector(getService:)]) return nil;
    return [center getService:cls];
}

// 创建菜单项：优先微信内置 SVG 图标（initWithTitle:svgName:target:action:）
static id ddMakeMenuItem(NSString *title, SEL action, NSString *svgName, id target) {
    Class itemClass = NSClassFromString(@"MMMenuItem");
    if (!itemClass) return nil;
    id item = nil;
    if ([itemClass instancesRespondToSelector:@selector(initWithTitle:svgName:target:action:)]) {
        item = [[itemClass alloc] initWithTitle:title svgName:svgName target:target action:action];
    } else if ([itemClass instancesRespondToSelector:@selector(initWithTitle:svgName:action:)]) {
        item = [[itemClass alloc] initWithTitle:title svgName:svgName action:action];
    } else if ([itemClass instancesRespondToSelector:@selector(initWithTitle:icon:target:action:)]) {
        item = [[itemClass alloc] initWithTitle:title icon:nil target:target action:action];
    } else if ([itemClass instancesRespondToSelector:@selector(initWithTitle:target:action:)]) {
        item = [[itemClass alloc] initWithTitle:title target:target action:action];
    }
    return item;
}

// 取图片消息数据；兼容不同微信版本（类方法 + 实例方法）
static NSData *ddGetMsgImageData(id wrap) {
    if (!wrap) return nil;
    Class msgWrapCls = NSClassFromString(@"CMessageWrap");
    if (!msgWrapCls) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL selHD  = NSSelectorFromString(@"getMsgHDImgData:");
    if ([msgWrapCls respondsToSelector:selHD])  return [msgWrapCls performSelector:selHD withObject:wrap];
    if ([wrap respondsToSelector:selHD])        return [wrap performSelector:selHD withObject:wrap];
    SEL selMid = NSSelectorFromString(@"getMsgHdOrMiddleImgData:");
    if ([msgWrapCls respondsToSelector:selMid]) return [msgWrapCls performSelector:selMid withObject:wrap];
    if ([wrap respondsToSelector:selMid])        return [wrap performSelector:selMid withObject:wrap];
#pragma clang diagnostic pop
    return nil;
}

// 把图片数据缩放到边长 <= max 的 PNG（对齐 WCP processImageData 的缩放步骤）
static NSData *ddResizeImageData(NSData *srcData, CGFloat maxSide) {
    if (!srcData) return nil;
    UIImage *img = [UIImage imageWithData:srcData];
    if (!img || img.size.width < 1 || img.size.height < 1) return srcData;
    CGFloat scale = MIN(1.0, maxSide / MAX(img.size.width, img.size.height));
    CGSize s = CGSizeMake((int)(img.size.width * scale), (int)(img.size.height * scale));
    UIGraphicsBeginImageContextWithOptions(s, NO, [UIScreen mainScreen].scale);
    [img drawInRect:CGRectMake(0, 0, s.width, s.height)];
    UIImage *r = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *d = UIImagePNGRepresentation(r);
    return d ?: srcData;
}

// 消息类型判定：严格按 m_uiMessageType 区分，表情优先于 IsImgMsg
// 微信：3=图片，47=表情。表情消息 m_nsEmoticonMD5 非空。
static BOOL ddIsEmoticonMessage(id wrap) {
    if (!wrap) return NO;
    unsigned int type = 0;
    if ([wrap respondsToSelector:@selector(m_uiMessageType)]) type = [wrap m_uiMessageType];
    if (type == 47) return YES;
    if ([wrap respondsToSelector:@selector(m_nsEmoticonMD5)]) {
        id md5 = [wrap m_nsEmoticonMD5];
        if ([md5 isKindOfClass:[NSString class]] && [md5 length] > 0) return YES;
    }
    return NO;
}
static BOOL ddIsImageMessage(id wrap) {
    if (!wrap) return NO;
    if (ddIsEmoticonMessage(wrap)) return NO;     // 表情绝不被当成图片
    unsigned int type = 0;
    if ([wrap respondsToSelector:@selector(m_uiMessageType)]) type = [wrap m_uiMessageType];
    if (type == 3) return YES;
    if ([wrap respondsToSelector:@selector(IsImgMsg)] && [wrap IsImgMsg]) return YES;
    return NO;
}

// 从 cell 取当前消息 wrap（WCP 在 filteredMenuItems 内通过 self.viewModel.messageWrap 判定）
static id ddCurrentWrap(id self) {
    @try {
        id vm = nil;
        if ([self respondsToSelector:@selector(viewModel)]) vm = [self viewModel];
        else vm = [(id)self valueForKey:@"viewModel"];
        if (!vm) return nil;
        if ([vm respondsToSelector:@selector(messageWrap)]) return [vm messageWrap];
        return [vm valueForKey:@"messageWrap"];
    } @catch (NSException *e) { return nil; }
}

// MARK: - 转表情（对齐 WCP：下载/取图 → 缩放 → emoticonMsgForImageData → 发送）

static void ddDoConvertImageToEmoticon(id wrap, int triesLeft) {
    @try {
        DDImageEmojiConfig *cfg = [DDImageEmojiConfig shared];
        NSData *imgData = ddGetMsgImageData(wrap);
        if (!imgData && triesLeft > 0) {
            // 对齐 WCP：图还没下载就先触发下载，再延迟重试
            id msgMgr = ddGetService(@"CMessageMgr");
            if (msgMgr && [msgMgr respondsToSelector:@selector(StartDownloadImage:HD:AutoDownload:SaveAlbum:Silent:behavior:)]) {
                [msgMgr StartDownloadImage:wrap HD:YES AutoDownload:YES SaveAlbum:NO Silent:YES behavior:0];
                DDLog(@"转表情: 本地无图数据，触发 StartDownloadImage 后重试(%d)", triesLeft);
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 800 * NSEC_PER_MSEC),
                           dispatch_get_main_queue(), ^{
                ddDoConvertImageToEmoticon(wrap, triesLeft - 1);
            });
            return;
        }
        if (!imgData) { DDLog(@"转表情失败: 取不到图数据（已重试）"); return; }

        NSData *finalData = ddResizeImageData(imgData, 240);
        DDLog(@"转表情: 取图成功 len=%lu，缩放后 len=%lu", (unsigned long)imgData.length, (unsigned long)finalData.length);

        Class emoMgrCls = NSClassFromString(@"CEmoticonMgr");
        if (!emoMgrCls) { DDLog(@"转表情失败: 找不到 CEmoticonMgr"); return; }

        if (cfg.enableImageToEmoticonDirectSend) {
            // 直接发送：生成表情消息并发送（WCP 原路）
            id errorMsg = nil;
            id newWrap = nil;
            if ([emoMgrCls respondsToSelector:@selector(emoticonMsgForImageData:errorMsg:)]) {
                newWrap = [emoMgrCls emoticonMsgForImageData:finalData errorMsg:&errorMsg];
            }
            if (newWrap) {
                if ([newWrap respondsToSelector:@selector(m_nsToUsr)] &&
                    [wrap respondsToSelector:@selector(m_nsToUsr)]) {
                    NSString *to = [wrap m_nsToUsr];
                    if (to.length) [newWrap setM_nsToUsr:to];   // 发回同一会话
                }
                id msgMgr = ddGetService(@"CMessageMgr");
                if (msgMgr && [msgMgr respondsToSelector:@selector(AddMsg:MsgWrap:)]) {
                    [msgMgr AddMsg:[newWrap m_nsToUsr] MsgWrap:newWrap];
                    DDLog(@"转表情: 已直接发送表情消息 to=%@", [newWrap m_nsToUsr]);
                } else {
                    DDLog(@"转表情失败: 找不到 CMessageMgr/AddMsg");
                }
            } else {
                DDLog(@"转表情失败: emoticonMsgForImageData 返回 nil (err=%@)", errorMsg);
            }
        } else {
            // 添加到表情面板（无需 UI，静默添加）
            Class addWrapCls = NSClassFromString(@"AddEmoticonWrap");
            id addWrap = nil;
            if (addWrapCls && [addWrapCls instancesRespondToSelector:@selector(initWithMessageWrap:AndSource:)]) {
                addWrap = [[addWrapCls alloc] initWithMessageWrap:wrap AndSource:1];
            }
            id emoMgr = ddGetService(@"CEmoticonMgr");
            if (addWrap && emoMgr &&
                [emoMgr respondsToSelector:@selector(AddCustomEmoticonWithData:addEmoticonWrap:isSilently:)]) {
                [emoMgr AddCustomEmoticonWithData:finalData addEmoticonWrap:addWrap isSilently:YES];
                DDLog(@"转表情: 已加入表情面板");
            } else {
                DDLog(@"转表情失败: AddEmoticonWrap/CEmoticonMgr 服务不可用");
            }
        }
    } @catch (NSException *e) {
        DDLog(@"转表情异常: %@", e);
    }
}

// MARK: - 保存表情到相册（对齐 WCP：取原文件 → 读 data → wxam 转 GIF → PHPhotoLibrary）

static void ddSaveImageToPhotoLibrary(UIImage *image, NSString *md5) {
    if (!image) { DDLog(@"保存失败: image 为空 md5=%@", md5); return; }
    void (^doSave)(void) = ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError *error) {
            DDLog(@"保存表情到相册 %@ %@", success?@"成功":@"失败", success?@"":[NSString stringWithFormat:@"(%@)", error]);
        }];
    };
    // 权限处理（iOS 14+）
    if (@available(iOS 14, *)) {
        PHAuthorizationStatus st = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
        if (st == PHAuthorizationStatusAuthorized || st == PHAuthorizationStatusLimited) { doSave(); }
        else { [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus s){ if (s!=PHAuthorizationStatusDenied) doSave(); else DDLog(@"保存失败: 相册无权限"); }]; }
    } else {
        PHAuthorizationStatus st = [PHPhotoLibrary authorizationStatus];
        if (st == PHAuthorizationStatusAuthorized) { doSave(); }
        else { [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus s){ if (s==PHAuthorizationStatusAuthorized) doSave(); else DDLog(@"保存失败: 相册无权限"); }]; }
    }
}

// MARK: - 菜单注入核心逻辑（共享，供多个入口调用）
// 在 givenMenu（可为 nil）基础上，按消息类型追加「转表情」/「保存」按钮。
// 返回一个新的可变数组，绝不返回 nil。

static NSMutableArray *ddInjectMenuItems(id cell, id items, NSString *entryName) {
    NSMutableArray *result = nil;
    if (items) {
        @try { result = [items mutableCopy]; } @catch (NSException *e) { result = nil; }
    }
    if (!result) result = [NSMutableArray array];

    @try {
        DDImageEmojiConfig *cfg = [DDImageEmojiConfig shared];
        if (!cfg.isEnabled) { DDLog(@"[%@] 功能开关全部关闭，跳过注入", entryName); return result; }

        id wrap = ddCurrentWrap(cell);
        BOOL isImage    = ddIsImageMessage(wrap);
        BOOL isEmoticon = ddIsEmoticonMessage(wrap);

        unsigned int type = 0;
        if ([wrap respondsToSelector:@selector(m_uiMessageType)]) type = [wrap m_uiMessageType];
        NSString *md5 = [wrap respondsToSelector:@selector(m_nsEmoticonMD5)] ? [wrap m_nsEmoticonMD5] : nil;
        DDLog(@"[%@] type=%u md5=%@ isImage=%d isEmoticon=%d (save=%d img2emo=%d)",
              entryName, type, md5, isImage, isEmoticon,
              cfg.enableSaveEmoticonToAlbum, cfg.enableImageToEmoticon);

        if (cfg.enableImageToEmoticon && isImage) {
            id item = ddMakeMenuItem(@"转表情", @selector(onDDImageToEmoticon:),
                                     @"icons_outlined_emoji_animal", cell);
            if (item) { [result addObject:item]; DDLog(@"[%@] 已加「转表情」", entryName); }
            else      { DDLog(@"[%@] 「转表情」创建失败(MMMenuItem 不可用)", entryName); }
        }
        if (cfg.enableSaveEmoticonToAlbum && isEmoticon) {
            id item = ddMakeMenuItem(@"保存", @selector(onDDSaveEmoticonToAlbum:),
                                     @"icons_filled_album", cell);
            if (item) { [result addObject:item]; DDLog(@"[%@] 已加「保存」", entryName); }
            else      { DDLog(@"[%@] 「保存」创建失败(MMMenuItem 不可用)", entryName); }
        }
    } @catch (NSException *e) {
        DDLog(@"[%@] 注入异常: %@", entryName, e);
    }
    return result;
}

// MARK: - Hook 1：BaseMessageCellView -filteredMenuItems:（WCP 原路径，子类未 override，覆盖所有 cell）

%hook BaseMessageCellView

- (id)filteredMenuItems:(id)items {
    id orig = %orig(items);
    return ddInjectMenuItems(self, orig, @"filteredMenuItems");
}

%new - (void)onDDImageToEmoticon:(id)sender {
    id wrap = ddCurrentWrap(self);
    DDLog(@"点击「转表情」");
    if (!wrap) { DDLog(@"转表情: 取不到当前消息 wrap"); return; }
    ddDoConvertImageToEmoticon(wrap, 3);
}

%new - (void)onDDSaveEmoticonToAlbum:(id)sender {
    DDLog(@"点击「保存」");
    id wrap = ddCurrentWrap(self);
    if (!wrap) { DDLog(@"保存: 取不到当前消息 wrap"); return; }
    NSString *md5 = [wrap respondsToSelector:@selector(m_nsEmoticonMD5)] ? [wrap m_nsEmoticonMD5] : nil;
    if (!md5.length) { DDLog(@"保存失败: m_nsEmoticonMD5 为空"); return; }

    // 主路径：getEmoticonImageByMD5 直接拿 UIImage
    Class emoMgrCls = NSClassFromString(@"CEmoticonMgr");
    UIImage *img = nil;
    if (emoMgrCls && [emoMgrCls respondsToSelector:@selector(getEmoticonImageByMD5:)]) {
        img = [emoMgrCls getEmoticonImageByMD5:md5];
    }
    // 兜底：pathOfEmoticonForMd5 拿原文件（支持动态 wxam→gif）
    if (!img) {
        id emoMgr = ddGetService(@"CEmoticonMgr");
        SEL selPath = NSSelectorFromString(@"pathOfEmoticonForMd5:needUpdateTime:ignoreWxAM:");
        if (emoMgr && [emoMgr respondsToSelector:selPath]) {
            __autoreleasing NSString *path = nil;
            @try {
                NSMethodSignature *sig = [emoMgr methodSignatureForSelector:selPath];
                if (sig) {
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:emoMgr];
                    [inv setSelector:selPath];
                    BOOL need = NO, ignore = YES;
                    [inv setArgument:&md5 atIndex:2];
                    [inv setArgument:&need atIndex:3];
                    [inv setArgument:&ignore atIndex:4];
                    [inv invoke];
                    [inv getReturnValue:&path];
                }
            } @catch (NSException *e) {}
            if ([path isKindOfClass:[NSString class]] && path.length) {
                NSData *data = [NSData dataWithContentsOfFile:path];
                if ([path.pathExtension.lowercaseString isEqualToString:@"wxam"]) {
                    SEL selGif = NSSelectorFromString(@"createGifFromWxAMData:");
                    if (emoMgr && [emoMgr respondsToSelector:selGif]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        img = [emoMgr performSelector:selGif withObject:data];
#pragma clang diagnostic pop
                    }
                } else {
                    img = [UIImage imageWithData:data];
                }
            }
        }
    }
    ddSaveImageToPhotoLibrary(img, md5);
}

%end

// MARK: - Hook 2：图片 cell 的 operationMenuItems:（ImageMessageCellView override 了基类，需单独 hook）
// 图片消息长按菜单走这里（常见微信版本）。

%hook ImageMessageCellView

- (id)operationMenuItems {
    id orig = %orig;
    return ddInjectMenuItems(self, orig, @"ImageCell.operationMenuItems");
}

%end

// MARK: - Hook 3：表情 cell 的 operationMenuItems:（EmoticonMessageCellView override 了基类）
// 表情消息长按菜单走这里（常见微信版本）。

%hook EmoticonMessageCellView

- (id)operationMenuItems {
    id orig = %orig;
    return ddInjectMenuItems(self, orig, @"EmojiCell.operationMenuItems");
}

%end

// MARK: - 设置界面

@interface WCTableViewManager : NSObject
@property(retain, nonatomic) NSMutableArray *sections;
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)clearAllSection;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
@property(retain, nonatomic) NSMutableArray *cells;
@property(copy, nonatomic) NSString *footerTitle;
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
@end

@interface DDImageEmojiLogViewController : UIViewController
@end

@interface DDImageEmojiSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
- (void)buildTable;
- (void)exportLog:(id)sender;
- (void)clearLog:(id)sender;
- (void)showLog:(id)sender;
@end

@implementation DDImageEmojiLogViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"调试日志";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    UITextView *tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    tv.text = [[DDImageEmojiLog shared] allText];
    [self.view addSubview:tv];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"复制" style:UIBarButtonItemStylePlain
                                       target:self action:@selector(copyAll:)];
}
- (void)copyAll:(id)sender {
    [UIPasteboard generalPasteboard].string = [[DDImageEmojiLog shared] allText];
    DDLog(@"日志已复制到剪贴板");
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"已复制"
                                                              message:@"全部日志已复制到剪贴板"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

@implementation DDImageEmojiSettingsViewController

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    if (!mgrCls) return;
    WCTableViewManager *mgr = [mgrCls alloc];
    _tableViewMgr = [mgr initWithFrame:[UIScreen mainScreen].bounds
                                 style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) { [self ensureTableViewMgr]; }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD图片表情增强";
    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (@available(iOS 11, *)) tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) return;
    [self.tableViewMgr clearAllSection];
    DDImageEmojiConfig *cfg = [DDImageEmojiConfig shared];

    // 功能开关
    WCTableViewSectionManager *sec = [secCls defaultSection];
    [sec addCell:[cellCls switchCellForSel:@selector(toggleSaveEmoticonToAlbum:)
                                     target:self
                                      title:@"保存表情包到图库"
                                         on:cfg.enableSaveEmoticonToAlbum]];
    [sec addCell:[cellCls switchCellForSel:@selector(toggleImageToEmoticon:)
                                     target:self
                                      title:@"启用图片转表情包"
                                         on:cfg.enableImageToEmoticon]];
    [sec addCell:[cellCls switchCellForSel:@selector(toggleImageToEmoticonDirectSend:)
                                     target:self
                                      title:@"转表情后直接发送"
                                         on:cfg.enableImageToEmoticonDirectSend]];
    if ([sec respondsToSelector:@selector(setFooterTitle:)]) {
        [sec setFooterTitle:@"长按图片或表情消息，使用增强选项。默认开启两个主功能。"];
    }
    [self.tableViewMgr addSection:sec];

    // 调试
    WCTableViewSectionManager *dbg = [secCls defaultSection];
    [dbg addCell:[cellCls normalCellForSel:@selector(showLog:)
                                    target:self
                                     title:@"查看调试日志"
                                rightValue:@""]];
    [dbg addCell:[cellCls normalCellForSel:@selector(exportLog:)
                                    target:self
                                     title:@"导出日志(复制+存文件)"
                                rightValue:@""]];
    [dbg addCell:[cellCls normalCellForSel:@selector(clearLog:)
                                    target:self
                                     title:@"清空日志"
                                rightValue:@""]];
    if ([dbg respondsToSelector:@selector(setFooterTitle:)]) {
        [dbg setFooterTitle:@"遇到问题请点「查看调试日志」并把内容发我，便于定位。"];
    }
    [self.tableViewMgr addSection:dbg];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleSaveEmoticonToAlbum:(UISwitch *)sender {
    [[DDImageEmojiConfig shared] setValue:sender.isOn ? @(1) : @(0)
                           forConfigKey:kDDImageEmojiEnableSaveEmoticonToAlbum];
    [self buildTable];
}
- (void)toggleImageToEmoticon:(UISwitch *)sender {
    [[DDImageEmojiConfig shared] setValue:sender.isOn ? @(1) : @(0)
                           forConfigKey:kDDImageEmojiEnableImageToEmoticon];
    [self buildTable];
}
- (void)toggleImageToEmoticonDirectSend:(UISwitch *)sender {
    [[DDImageEmojiConfig shared] setValue:sender.isOn ? @(1) : @(0)
                           forConfigKey:kDDImageEmojiEnableImageToEmoticonDirectSend];
    [self buildTable];
}

- (void)showLog:(id)sender {
    DDImageEmojiLogViewController *vc = [DDImageEmojiLogViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)exportLog:(id)sender {
    NSString *text = [[DDImageEmojiLog shared] allText];
    [UIPasteboard generalPasteboard].string = text;
    // 额外存一份到 Documents，方便用文件管理器导出
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count) {
            NSString *doc = [paths firstObject];
            NSString *dst = [doc stringByAppendingPathComponent:@"DDImageEmoji_log.txt"];
            [text writeToFile:dst atomically:YES encoding:NSUTF8StringEncoding error:nil];
            DDLog(@"日志已导出到: %@", dst);
        }
    } @catch (NSException *e) {}
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"日志已导出"
                                                              message:@"已复制到剪贴板，并保存到微信 Documents/DDImageEmoji_log.txt"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)clearLog:(id)sender {
    [[DDImageEmojiLog shared] clear];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"已清空"
                                                              message:@"调试日志已清空"
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end

// MARK: - 注册入口（参考 DD显示原始wxid 插件的 WCPluginsMgr 注册）

%ctor {
    @autoreleasepool {
        // 强制写一条启动日志并同步落盘到 Documents，用于判断 tweak 是否真正加载
        [[DDImageEmojiLog shared] appendSync:@"===== DD图片表情增强 v1.2.0 注入开始 ====="];
        [[DDImageEmojiLog shared] appendSync:@"进程启动，%ctor 已执行（tweak 已加载）"];
        [[DDImageEmojiLog shared] appendSync:@"钩子：filteredMenuItems / ImageCell.operationMenuItems / EmojiCell.operationMenuItems"];
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD图片表情增强"
                                                      version:@"1.2.0"
                                                   controller:@"DDImageEmojiSettingsViewController"];
            [[DDImageEmojiLog shared] appendSync:@"已注册设置入口(WCPluginsMgr)"];
        } else {
            [[DDImageEmojiLog shared] appendSync:@"未找到 WCPluginsMgr，设置入口未注册（功能仍生效）"];
        }
    }
}
