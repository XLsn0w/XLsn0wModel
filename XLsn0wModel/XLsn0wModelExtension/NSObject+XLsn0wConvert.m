
#import "NSObject+XLsn0wConvert.h"
#import "XLsn0wModelType.h"

@implementation NSObject (XLsn0wConvert)

/**
 *  利用block循环遍历Class的每个属性
 *
 *  @param block 遍历回调的block
 */
+ (void)enumerateMembersUsingBlock:(void (^)(XLsn0wModelMember *, BOOL *))block{
    
    static const char WFCachedMembersKey;
    // 获得成员变量
    NSMutableArray *cachedMembers = objc_getAssociatedObject(self, &WFCachedMembersKey);
    if (cachedMembers == nil) {
        cachedMembers = [NSMutableArray array];
        
        // 通过运行时，获取属性列表
        uint outCount = 0;  // 成员属性个数
        Ivar *varList = class_copyIvarList(self, &outCount);
        
        // 循环获取成员属性，并回调block
        for (int i = 0; i < outCount; ++i) {
            XLsn0wModelMember *member = [XLsn0wModelMember memberWithIvar:varList[i]];
            [cachedMembers addObject:member];
        }
        free(varList);
        objc_setAssociatedObject(self, &WFCachedMembersKey, cachedMembers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL stop = FALSE;
    
    for (XLsn0wModelMember *member in cachedMembers) {
        block(member, &stop);
        if(stop) break;
    }
    // 3.释放内存
}
/**
 *  通过字典配置对象属性
 *
 *  @param dict 配置字典
 */
- (void)configDictionary:(NSDictionary *)dict{
    [[self class] enumerateMembersUsingBlock:^(XLsn0wModelMember *member, BOOL *stop) {
        // 属性名称
        NSString *memName = member.name;
        NSString *memType = member.type;
        // 默认值
        id memValue       = dict[memName];
        
        if(!memValue) return;
        
        /**************************************************************
         *
         *  若member是NSArray dict[member.name]应该是字典数组
         *  需要将字典数组转化为模型数组
         *
         *************************************************************/
        if([memType rangeOfString:@"NSArray"].length > 0) {
            // 需要用户实现了获取数组中成员类方法并且返回字典中可以查询到当前属性所属的 "类"
            if ([self respondsToSelector:@selector(getDictionaryFromKeyIsNSArrayMatchValueIsClassName)] && [self getDictionaryFromKeyIsNSArrayMatchValueIsClassName][memName]) {
                Class memClass = NSClassFromString([self getDictionaryFromKeyIsNSArrayMatchValueIsClassName][memName]);
                // 递归调用创建模型数组
                memValue       = [memClass objcsWithDictArray:memValue];
            }
        }
        
        /**************************************************************
         *
         *  若member是自定义对象 dict[member.name] 应该是个字典,
         *  递归调用进行配置，将字典转化为对象
         *
         *************************************************************/
        else if(![XLsn0wModelType isBasicType:memType] && ![XLsn0wModelType isFoundationType:memType])
        {
            memValue = [[NSClassFromString(memType) alloc] initWithDictionary:memValue];
        }
        
        /**************************************************
         *
         *  类型转换处理
         *
         *************************************************/
        else {
            memValue = [XLsn0wModelType reviseType:memType withValue:memValue];
        }
        // 若member是系统对象
        [self setValue:memValue forKey:memName];
    }];
}

/**
 *  使用字典初始化一个对象
 *
 *  @param dict 配置字典
 *
 *  @return 初始化好的对象
 */
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if(self = [self init]) {
        [self configDictionary:dict];
    }
    return self;
}

/**
 *  通过字典数组初始化对象数组
 *
 *  @param dictArray 配置字典数组
 *
 *  @return 初始化好的对象数组
 */
+ (NSArray *)objcsWithDictArray:(NSArray *)dictArray{
    NSMutableArray *objcs = [NSMutableArray arrayWithCapacity:dictArray.count];
    if( [NSStringFromClass([self class]) hasPrefix:@"NS"]) {
        /** Foundation 自带数据类型 */
        for (id key in dictArray) {
            if( [key isMemberOfClass:[self class]]) {
                /** 数组内容非目标数组内容 */
                return nil;
            }
        }
        return dictArray.copy;
    }
    for (int i = 0; i < dictArray.count; ++i) {
        NSDictionary *dict = dictArray[i];
        id obj = [[self alloc] initWithDictionary:dict];
        [objcs addObject:obj];
    }
    
    return [objcs copy];
}

/**
 *  模型转字典
 *
 *  @return 字典对象
 */
- (NSMutableDictionary *)keyValues {
    return [self keyValuesWithMap:nil];
}

/**
 *  模型转字典
 *
 *  @return 字典对象
 */
- (NSMutableDictionary *)keyValuesWithMap:(NSDictionary *)map {
    
    NSMutableDictionary *keyValues = [NSMutableDictionary dictionary];
    
    if([XLsn0wModelType isBasicType:NSStringFromClass([self class])] || [XLsn0wModelType isFoundationType:NSStringFromClass([self class])])
    {
        return (NSMutableDictionary *)self;
    }
    
    [[self class] enumerateMembersUsingBlock:^(XLsn0wModelMember *member, BOOL *stop) {
        
        // 属性名称
        NSString *memName  = member.name;
        NSString *memType  = member.type;
        id        memValue = [self valueForKey:memName];
        
        if(!memValue)
        {
            [keyValues setValue:[NSNull null] forKey:memName];
            return;
        }
        
        /**************************************************************
         *
         *  若member是NSArray dict[member.name]应该是字典数组
         *  需要将模型数组转化为字典数组
         *
         *************************************************************/
        if([memType rangeOfString:@"NSArray"].length > 0)
        {
            NSArray *subObjc = (NSArray *)memValue;
            NSMutableArray *subValues = [NSMutableArray arrayWithCapacity:subObjc.count];
            [subObjc enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [subValues addObject:[obj keyValuesWithMap:map]];
            }];
            memValue = subValues;
        }
        
        /**************************************************************
         *
         *  若member是自定义对象 dict[member.name] 应该是个字典,
         *  递归调用进行配置，将对象转化为字典
         *
         *************************************************************/
        else if(![XLsn0wModelType isBasicType:memType] && ![XLsn0wModelType isFoundationType:memType])
        {
            memValue = [memValue keyValuesWithMap:map];
        }
        /**************************************************
         *
         *  类型转换处理
         *
         *************************************************/
        else {
            memValue = [XLsn0wModelType reviseType:memType withValue:memValue];
        }
        // 若member是系统对象
        [keyValues setValue:memValue forKey:memName];
    }];
    
    return keyValues;
}

@end

@implementation XLsn0wModelMember

#pragma mark ------<初始化>

- (instancetype)initWithIvar:(Ivar)var{
    if(self = [super init])
    {
        // 获取属性全名称
        _fullName = [NSString stringWithUTF8String:ivar_getName(var)];
        // 获取属性名称
        _name = [_fullName hasPrefix:@"_"] ? [_fullName substringFromIndex:1] : _fullName;
        // 当前格式为：@"类型名称"
        _type = [NSString stringWithUTF8String:ivar_getTypeEncoding(var)];
        // 更改格式，去除 @ 及 " 符号;
        if ([_type hasPrefix:@"@\""]) {
            _type = [_type substringWithRange:NSMakeRange(2, _type.length - 3)];
        }
        // 记录原始的var
        _srcIvar = var;
    }
    return self;
}
/**
 *  通过Ivar初始化类方法
 *
 *  @param var 通过运行时获取的Ivar变量
 *
 *  @return 转换过的成员变量类型
 */
+ (instancetype)memberWithIvar:(Ivar)var{
    return [[self alloc] initWithIvar:var];
}

@end
