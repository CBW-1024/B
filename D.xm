// DDFoldedChatPin
// 启用折叠的群聊置顶：默认生效，无设置界面。
// 功能意图：把微信"折叠的群聊"那个特殊会话（运行时标识 chatroom_session_box）持续钉在会话列表顶部。
// 实现基于锤子 (WeChatTweak.dylib) 反汇编还原的微信 API 调用链：
//   MMContext currentContext -> getService:MMNewSessionMgr / CContactMgr
//   -> CContactMgr getContactByName: -> MMNewSessionMgr setContact:sessionTop:sync:
// 这些类的私有方法声明仅用于编译期签名，实现来自微信二进制。

#import <UIKit/UIKit.h>

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)service;
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(id)name;
@end

@interface MMNewSessionMgr : NSObject
- (BOOL)setContact:(id)contact sessionTop:(BOOL)top sync:(BOOL)sync;
- (void)UntopSessionByName:(id)name;
@end

// 折叠群聊在微信运行时里的特殊会话标识（锤子 dylib 中写死为 getContactByName: 的实参）
static NSString *const kDDFoldedChatSessionName = @"chatroom_session_box";

// 把折叠群聊会话钉在顶部。幂等：已置顶时再置顶无副作用。
static void DDFPinFoldedChatSession(void) {
    MMContext *ctx = [%c(MMContext) currentContext];
    if (!ctx) return;
    id sessionMgr = [ctx getService:[%c(MMNewSessionMgr) class]];
    id contactMgr = [ctx getService:[%c(CContactMgr) class]];
    if (!sessionMgr || !contactMgr) return;

    id contact = [contactMgr getContactByName:kDDFoldedChatSessionName];
    if (!contact) return;

    [sessionMgr setContact:contact sessionTop:YES sync:YES];
}

%hook UIApplication

// 进入前台时确保折叠群聊会话保持置顶（默认生效，无需任何开关）
- (void)applicationDidBecomeActive:(id)application {
    %orig;
    // 微信上下文与置顶写入应在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        DDFPinFoldedChatSession();
    });
}

%end
