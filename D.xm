// DD好友添加精确时间
// 在联系人详情页显示好友的精确添加时间，格式：yyyy/MM/dd HH:mm:ss
// 默认生效，无需开关配置
//
// 原理：
// 1. 微信原生已内置"添加时间"显示功能（SocialInfomationViewController
//    addContactAddCreateTimeCellAtSection:），但默认格式不含时分秒。
// 2. 本插件 hook 该方法：先调用 %orig 让微信原生创建"添加时间" cell，
//    再获取联系人的添加时间戳（CContact.m_uiAddCreateTime），
//    用 NSDateFormatter 格式化为 "yyyy/MM/dd HH:mm:ss"，
//    最后更新新创建 cell 的显示文本。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口

// CContact：微信联系人，m_uiAddCreateTime 为添加时间戳（秒）
@interface CContact : NSObject
@property(nonatomic) unsigned int m_uiAddCreateTime;
@end

// SocialInfomationViewController：微信联系人详情页
@interface SocialInfomationViewController : UIViewController
@property(retain, nonatomic) CContact *m_contact;
- (void)addContactAddCreateTimeCellAtSection:(id)section;
@end

// WCTableViewSectionManager：微信表格分区，cells 为 cell 管理器数组
@interface WCTableViewSectionManager : NSObject
@property(retain, nonatomic) NSMutableArray *cells;
@end

// WCTableViewCellNormalConfig：cell 配置
@interface WCTableViewCellNormalConfig : NSObject
@property(retain, nonatomic) id rightConfig;
@end

// WCTableViewCellRightConfig：右侧配置，detail 为右侧文本
@interface WCTableViewCellRightConfig : NSObject
@property(copy, nonatomic) NSString *detail;
@end

// WCTableViewNormalCellManager：普通 cell 管理器
@interface WCTableViewNormalCellManager : NSObject
@property(retain, nonatomic) WCTableViewCellNormalConfig *cellConfig;
@end

#pragma mark - 插件主逻辑

%hook SocialInfomationViewController

// 拦截"添加时间" cell 的创建，修改时间显示格式
- (void)addContactAddCreateTimeCellAtSection:(id)section {
    // 记录 %orig 前 section 的 cell 数量
    NSUInteger beforeCount = 0;
    if ([section respondsToSelector:@selector(cells)]) {
        beforeCount = ((WCTableViewSectionManager *)section).cells.count;
    }

    // 调用微信原生逻辑（创建"添加时间" cell）
    %orig;

    // 获取联系人
    CContact *contact = self.m_contact;
    if (!contact) return;
    if (![contact respondsToSelector:@selector(m_uiAddCreateTime)]) return;

    // 获取添加时间戳（秒）
    unsigned int addTime = contact.m_uiAddCreateTime;
    if (addTime == 0) return;

    // 格式化为 yyyy/MM/dd HH:mm:ss
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:addTime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSString *timeString = [formatter stringFromDate:date];

    // 获取 section 的 cells
    if (![section respondsToSelector:@selector(cells)]) return;
    WCTableViewSectionManager *sec = (WCTableViewSectionManager *)section;
    NSArray *cells = sec.cells;
    if (cells.count == 0) return;

    // 优先处理 %orig 后新增的 cell（即"添加时间" cell）
    Class normalCls = objc_getClass("WCTableViewNormalCellManager");
    NSUInteger startIdx = MIN(beforeCount, cells.count);

    for (NSUInteger i = startIdx; i < cells.count; i++) {
        id cell = cells[i];
        if (!normalCls || ![cell isKindOfClass:normalCls]) continue;
        WCTableViewNormalCellManager *normalCell = (WCTableViewNormalCellManager *)cell;

        WCTableViewCellNormalConfig *cellConfig = normalCell.cellConfig;
        if (!cellConfig) continue;
        WCTableViewCellRightConfig *rightConfig = cellConfig.rightConfig;
        if (!rightConfig) continue;

        // 替换右侧文本为精确添加时间
        rightConfig.detail = timeString;
    }
}

%end
