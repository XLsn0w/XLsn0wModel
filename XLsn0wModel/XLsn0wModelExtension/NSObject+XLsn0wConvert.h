
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface XLsn0wModelMember : NSObject {
    Ivar _srcIvar;/// 可以被子类继承，但对外部是只读访问
}
/** 成员属性类型(只读) */
@property (nonatomic, copy, readonly) NSString *type;
/** 成员属性名称(只读) */
@property (nonatomic, copy, readonly) NSString *name;
/** 成员属性全称(只读) */
@property (nonatomic, copy, readonly) NSString *fullName;
/** 原始的Ivar(只读)  */
@property (nonatomic, assign, readonly) Ivar srcIvar;

/**
 *  通过Ivar初始化类方法
 *
 *  @param var 通过运行时获取的Ivar变量
 *
 *  @return 转换过的成员变量类型
 */
+ (instancetype)memberWithIvar:(Ivar)var;

@end

@protocol XLsn0wConvertProtocol <NSObject>
/**************************************************************
 *
 *  TODO:这里通过增加协议，根据函数获取数组类型列表
 *  还可以通过运行时，直接增加字典属性，这样会不会增加内存消耗
 *
 *************************************************************/
@optional
- (NSDictionary *)getDictionaryFromKeyIsNSArrayMatchValueIsClassName;///重写方法 里面把一级Model的Key是NSArray配对二级Model的类名作为Value返回字典类型
///return @{@"Array" : NSStringFromClass([ArrayModel class])};
@end

@interface NSObject (XLsn0wConvert) <XLsn0wConvertProtocol>

/**
 *  利用block循环遍历Class的每个属性
 *
 *  @param block 遍历回调的block
 */
+ (void)enumerateMembersUsingBlock:(void (^)(XLsn0wModelMember *member, BOOL *stop))block;

/**
 *  通过字典配置对象属性
 *
 *  @param dict 配置字典
 */
- (void)configDictionary:(NSDictionary *)dict;

/**
 *  使用字典初始化一个对象
 *
 *  @param dict 配置字典
 *
 *  @return 初始化好的对象
 */
- (instancetype)initWithDictionary:(NSDictionary *)dict;

/**
 *  通过字典数组初始化对象数组
 *
 *  @param dictArray 配置字典数组
 *
 *  @return 初始化好的对象数组
 */
+ (NSArray *)objcsWithDictArray:(NSArray *)dictArray;


/**
 *  模型转字典
 *
 *  @return 字典对象
 */
- (NSMutableDictionary *)keyValues;
- (NSMutableDictionary *)keyValuesWithMap:(NSDictionary *)map;///Java中Map和Dictionary类似

@end
