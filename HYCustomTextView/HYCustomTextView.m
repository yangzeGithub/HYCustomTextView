//
//  HYCustomTextView.m
//  HYCustomTextView
//
//  Created by 杨泽 on 2017/5/30.
//  Copyright © 2017年 yangze. All rights reserved.
//

#import "HYCustomTextView.h"

CGFloat const kFSTextViewPlaceholderVerticalMargin = 8.0; ///< placeholder垂直方向边距
CGFloat const kFSTextViewPlaceholderHorizontalMargin = 6.0; ///< placeholder水平方向边距

@interface HYCustomTextView ()

@property (nonatomic, copy) HYCustomTextViewHandler changeHandler; ///< 文本改变Block
@property (nonatomic, copy) HYCustomTextViewHandler maxHandler; ///< 达到最大限制字符数Block
@property (nonatomic, copy) HYCustomTextViewHandler frameChangeHandler; ///< 达到最大限制字符数Block

@property (nonatomic, assign) CGFloat               lastHeight;



@property(nonatomic,strong) UILabel *placeholderLabel;

@end

@implementation HYCustomTextView

#pragma mark - Getter
- (UILabel *)placeholderLabel {
    if (!_placeholderLabel) {
        
        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.numberOfLines = 0;
        _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _placeholderLabel;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initialize];
    }
    return self;
}

// 成为第一响应者
- (BOOL)becomeFirstResponder {
    BOOL become = [super becomeFirstResponder];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:UITextViewTextDidChangeNotification object:nil];
    return become;
}

// 注销第一响应者时移除文本变化的通知, 以免影响其它的`UITextView`对象.
- (BOOL)resignFirstResponder {
    BOOL resign = [super resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
    return resign;
}

#pragma mark - Private
- (void)initialize {
    
    if (_maxLength == 0 || _maxLength == NSNotFound) {
        _maxLength = NSUIntegerMax;
    }
    
    if (!_placeholderColor) {
        _placeholderColor = [UIColor colorWithRed:0.780 green:0.780 blue:0.804 alpha:1.000];
    }
    
    // 基本设定 (需判断是否在Storyboard中设置了值)
    if (!self.backgroundColor) {
        self.backgroundColor = [UIColor whiteColor];
    }
    
    if (!self.font) {
        self.font = [UIFont systemFontOfSize:15.f];
    }
    
    self.scrollEnabled = NO;
    
    self.allowFirstStringEmpt = YES;
    
    // placeholderLabel
    self.placeholderLabel.font = self.font;
    self.placeholderLabel.text = _placeholder;
    self.placeholderLabel.textColor = _placeholderColor;
    [self addSubview:self.placeholderLabel];
    
    self.minHeight = [self singleTextHeight];
    
    // constraint
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.placeholderLabel
                                                     attribute:NSLayoutAttributeTop
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeTop
                                                    multiplier:1.0
                                                      constant:kFSTextViewPlaceholderVerticalMargin]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.placeholderLabel
                                                     attribute:NSLayoutAttributeLeft
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeLeft
                                                    multiplier:1.0
                                                      constant:kFSTextViewPlaceholderHorizontalMargin]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.placeholderLabel
                                                     attribute:NSLayoutAttributeWidth
                                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeWidth
                                                    multiplier:1.0
                                                      constant:-kFSTextViewPlaceholderHorizontalMargin*2]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.placeholderLabel
                                                     attribute:NSLayoutAttributeHeight
                                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeHeight
                                                    multiplier:1.0
                                                      constant:-kFSTextViewPlaceholderVerticalMargin*2]];
}


#pragma mark - NSNotification
- (void)textDidChange:(NSNotification *)notification {
    // 通知回调的实例的不是当前实例的话直接返回
    if (notification.object != self) return;
    // 根据字符数量显示或者隐藏 `placeholderLabel`
    self.placeholderLabel.hidden = [@(self.text.length) boolValue];
    // 禁止第一个字符输入空格或者换行
    if (self.allowFirstStringEmpt) {
        if (self.text.length == 1) {
            if ([self.text isEqualToString:@" "] || [self.text isEqualToString:@"\n"]) {
                self.text = @"";
            }
        }
    }
    
    // 限制字符数.
    if (_maxLength != NSUIntegerMax && _maxLength != 0 && self.text.length > 0) {
        if (!self.markedTextRange && self.text.length > _maxLength) {
            !_maxHandler ?: _maxHandler(self); // 回调达到最大限制的Block.
            self.text = [self.text substringToIndex:_maxLength]; // 截取最大限制字符数.
            [self.undoManager removeAllActions]; // 达到最大字符数后清空所有 undoaction, 以免 undo 操作造成crash.
        }
    }
    
    if (self.needLayoutHeight) {
        CGSize newSize = [self sizeThatFits:CGSizeMake(self.frame.size.width,MAXFLOAT)];
        CGFloat textViewH = newSize.height;
        
        if (self.maxHeight > self.minHeight && textViewH > self.maxHeight) {
            self.scrollEnabled = YES;
            CGRect selfFrame = self.frame;
            selfFrame.size = CGSizeMake(self.frame.size.width, self.maxHeight);
            self.frame = selfFrame;            
        }else {
            // 设置为NO避免换行时bug
            self.scrollEnabled = NO;
            // 高度对比
            if (self.lastHeight != textViewH) {
                if (textViewH < self.minHeight) {
                    CGRect selfFrame = self.frame;
                    selfFrame.size.height = self.minHeight;
                    self.frame = selfFrame;
                }else {
                    CGRect selfFrame = self.frame;
                    selfFrame.size = CGSizeMake(self.frame.size.width, textViewH);
                    self.frame = selfFrame;
                }
                self.lastHeight = textViewH;
                // 高度变化回调
                !_frameChangeHandler?: _frameChangeHandler(self);
            }
        }
    }
    // 回调文本改变的Block.
    !_changeHandler ?: _changeHandler(self);
}

- (CGFloat)textViewHeight {
    //---- 计算高度 ---- //
    CGSize size = CGSizeMake(self.frame.size.width, CGFLOAT_MAX);
    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.font,NSFontAttributeName, nil];
    CGFloat textHeight = [self.text boundingRectWithSize:size
                                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                              attributes:dic
                                                 context:nil].size.height;
    return textHeight;
}

- (CGFloat)singleTextHeight {
    //---- 计算高度 ---- //
    CGSize size = CGSizeMake(self.frame.size.width, CGFLOAT_MAX);
    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:self.font,NSFontAttributeName, nil];
    CGFloat textHeight = [@"单" boundingRectWithSize:size
                                            options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                         attributes:dic
                                            context:nil].size.height;
    return textHeight;
}


#pragma mark - Setter

- (void)setText:(NSString *)text {
    [super setText:text];
    self.placeholderLabel.hidden = [@(text.length) boolValue];
    // 手动模拟触发通知
    NSNotification *notification = [NSNotification notificationWithName:UITextViewTextDidChangeNotification object:self];
    [self textDidChange:notification];
}

- (void)setFont:(UIFont *)font {
    [super setFont:font];
    self.placeholderLabel.font = font;
}

- (void)setMaxLength:(NSUInteger)maxLength {
    _maxLength = fmax(0, maxLength);
    self.text = self.text;
}

- (void)setPlaceholder:(NSString *)placeholder {
    if (!placeholder) return;
    _placeholder = [placeholder copy];
    if (_placeholder.length > 0) {
        self.placeholderLabel.text = _placeholder;
    }
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    if (!placeholderColor) return;
    _placeholderColor = placeholderColor;
    self.placeholderLabel.textColor = _placeholderColor;
}

- (void)setPlaceholderFont:(UIFont *)placeholderFont {
    if (!placeholderFont) return;
    _placeholderFont = placeholderFont;
    self.placeholderLabel.font = _placeholderFont;
}

- (void)setMinHeight:(CGFloat)minHeight {
    _minHeight = minHeight;
    if (minHeight < [self singleTextHeight]) {
        _minHeight = [self singleTextHeight];
    }
}

- (NSString *)formatText {
    return [[super text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; // 去除首尾的空格和换行.
}

- (void)addTextDidChangeHandler:(HYCustomTextViewHandler)changeHandler {
    _changeHandler = [changeHandler copy];
}

- (void)addTextLengthDidMaxHandler:(HYCustomTextViewHandler)maxHandler {
    _maxHandler = [maxHandler copy];
}

// 设定文字高度发生改变时回调
- (void)addTextViewHeightDidChangeHandler:(HYCustomTextViewHandler)changeHandler {
    _frameChangeHandler = [changeHandler copy];
}

@end
