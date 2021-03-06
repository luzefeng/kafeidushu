//
//  ViewController.m
//  Paging
//
//  Created by Eric Yang on 13-5-23.
//  Copyright (c) 2013年 Eric Yang. All rights reserved.
//

#import "ReaderViewController.h"
#import "PageInfo.h"
#import "PageInfoManage.h"
#import "BookMarkManage.h"
#import "BookMarkViewController.h"
#import "BookInfo.h"
#import "BookInfoManage.h"
#import "BookTheme.h"
#import "BookThemeManage.h"

/*
 fontSize vs offset  (iphone5)
 8-24
 
 24	393
 20	717
 14	883
 12	1224
 10	1998
 8	2524
 */

#define FONT_VALUE_WITH_SLIDE(v) (16*v +8)
#define SLIDE_VALUE_WITH_FONT(v) ((v-8)/16.0)

//#define ALPHA_VALUE_WITH_SLIDE(v) (-0.5*v+0.5)
//#define SLIDE_VALUE_WITH_ALPHA(v) ((v-0.5)/(-0.5))
#define ALPHA_VALUE_WITH_SLIDE(v) (-0.8*v+0.8)
#define SLIDE_VALUE_WITH_ALPHA(v) ((v-0.8)/(-0.8))


#define READ_TRY_COUNT_MAX 4

#define MAX_CHARACTER_LENGHT (4000)

#define MAX_PAGING_STEP 40 //单位piwxel,大概一行





#define  e_can_show_one_page -1




@implementation ReaderViewController{

    
    
    int referTotalPages;
    int referCharatersPerPage;
    
    NSRange* rangeOfPages;
    
    int preOffset;
    int currentOffset;
    int nextOffset;
    int currentLength;
    int maxLength;
    int currentPageIndex;
    
    
    PageInfoManage* pageInfoManage;
    
    long long fileLength;
    
    BOOL isBottomMenuShowing;
    BOOL isSimpleViewShowing;
    
    int fontSize;
    
    CFStringEncoding suitableEncoding; //init is INT32_MAX 
    
}
@synthesize  lbContent;
@synthesize vPageBg=_vPageBg;
@synthesize pageInfoLabel;
@synthesize text=_text;
@synthesize filePath=_filePath;
@synthesize fileName=_fileName;
@synthesize lbContentAdapter=_lbContentAdapter;
@synthesize pagingContent=_pagingContent;
@synthesize vMenu=_vMenu;
@synthesize btMenuSet=_btMenuSet;
@synthesize btMenuTool=_btMenuTool;
@synthesize vMenuTool=_vMenuTool;
@synthesize vMenuJump=_vMenuJump;
@synthesize vMenuSetting=_vMenuSetting;
@synthesize vJump=_vJump;
@synthesize vTheme=_vTheme;
@synthesize vFont=_vFont;
@synthesize vLight=_vLight;
@synthesize vCover=_vCover;


#pragma mark paging
// return current page character length
- (int)pageString:(NSString*)content isNext:(BOOL)isNext
{
    //text 整个文本内容
    
//    NSLog(@"-----pageString   -----before text:\n%@\n\n",content);
    
    //NSTimeInterval timeStart=[[[[NSDate alloc]init]autorelease]timeIntervalSince1970];
    // 计算文本串的大小尺寸
    CGSize totalTextSize = [content sizeWithFont:[UIFont systemFontOfSize:fontSize]
                                 constrainedToSize:CGSizeMake(lbContent.frame.size.width, CGFLOAT_MAX)
                                     lineBreakMode:NSLineBreakByWordWrapping];
//    //NSLog(@"time interval--pageString ---1--:%lf\n%@",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart,content);
    //NSLog(@"time interval--pageString ---11--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    NSLog(@"content:%d",content.length);
    //NSLog(@"time interval--pageString ---12--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    // 如果一页就能显示完，直接显示所有文本串即可。
    if (totalTextSize.height < lbContent.frame.size.height) {
        lbContent.text = content;
        self.pagingContent=content;
        NSLog(@"----- all text can be show in only one page -----end \n\n");
        return [content lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    }
    else {
        // 计算理想状态下的页面数量和每页所显示的字符数量，只是拿来作为参考值用而已！
        NSUInteger textLength = [content length];//总字符数 524
        referTotalPages = (int)totalTextSize.height/(int)lbContent.frame.size.height+1;//页数
        referCharatersPerPage = textLength/referTotalPages;//每页字符数
        
        // 申请最终保存页面NSRange信息的数组缓冲区
        int maxPages = referTotalPages;
        rangeOfPages=nil;
        rangeOfPages = (NSRange *)malloc(referTotalPages*sizeof(NSRange));
        memset(rangeOfPages, 0x0, referTotalPages*sizeof(NSRange));
        
        // 页面索引
        int page = 0;
        
        
        // 先计算临界点（尺寸刚刚超过UILabel尺寸时的文本串）
        NSRange range = NSMakeRange(isNext?0:textLength-referCharatersPerPage, referCharatersPerPage);//首页range
        
        // reach end of text ?
        NSString *pageText; //当前page的content
        CGSize pageTextSize;//content做占用的单行最大长度
        
        
        //NSLog(@"time interval--pageString ---2--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
        //得到合适的range
        //保证没有达到文章尾部
        while (isNext?(range.location + range.length < textLength):(range.location >0)) {
            pageText = [content substringWithRange:range];
            
            pageTextSize = [pageText sizeWithFont:[UIFont systemFontOfSize:fontSize]
                                constrainedToSize:CGSizeMake(lbContent.frame.size.width, CGFLOAT_MAX)
                                    lineBreakMode:NSLineBreakByWordWrapping];
            
            //如果填充满，则停止
            if (pageTextSize.height > lbContent.frame.size.height) {
                break;
            }
            else {
                //否则，再加上/下一页继续填充
                if(isNext){
                    //range总长度加 referCharatersPerPage，起点前移referCharatersPerPage
                    range.length += referCharatersPerPage;
                }else{
                    range.location-=referCharatersPerPage;
                    range.length += referCharatersPerPage;
                }
                
            }
        }
        //NSLog(@"time interval--pageString ---3--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
        //到文章结尾/开头时候处理
        if (range.location <= 0) {
            range.location = 0;
        }
        if (range.location + range.length >= textLength) {
            if(isNext){
                range.length = textLength - range.location;
            }else{
                range.location = textLength - range.length;
            }
            
        }
        
        
        // 然后一个个缩短字符串的长度，当缩短后的字符串尺寸小于lbContent的尺寸时即为满足
        int step=MAX_PAGING_STEP;
//        //NSTimeInterval timeStart=[[[[NSDate alloc]init]autorelease]timeIntervalSince1970];
        while (1) {
            pageText = [content substringWithRange:range];
//            NSLog(@"range.location:%d range.length:%d",range.location,range.length);
//            NSLog(@"pageText:%@",pageText);
            //得到前面计算得到的当页string
            pageTextSize = [pageText sizeWithFont:[UIFont systemFontOfSize:fontSize]
                                constrainedToSize:CGSizeMake(lbContent.frame.size.width, CGFLOAT_MAX)
                                    lineBreakMode:NSLineBreakByWordWrapping];
            
            
            //TODO 得到合适的，记录，不然循环太多
//            NSLog(@"pageTextSize.height:%f ;lbContent.frame.size.height:%f",pageTextSize.height,lbContent.frame.size.height);
            if (pageTextSize.height <= lbContent.frame.size.height) {
                if (step==MAX_PAGING_STEP) {
                    if(isNext){
                        range.length += step;
                    }else{
                        range.location -= step;
                        range.length+=step;
                    }
                    step=1;
                } else {
                    if(isNext){
                        range.length = [pageText length];
                    }else{
                        range.location = textLength-[pageText length];
                    }
                    
                    break;
                }
                
            }
            else {
                if(isNext){
                    range.length -= step;
			    }else{
                    range.location += step;
                    range.length-=step;
			    }
                
            }
        }
        //NSLog(@"time interval--pageString ---5--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
//        //NSLog(@"time interval--viewDidLoad ---4--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
        
        // 得到一个页面的显示范围
        if (page >= maxPages) {
            maxPages += 10;
            rangeOfPages = (NSRange *)realloc(rangeOfPages, maxPages*sizeof(NSRange));
        }
        rangeOfPages[0] = range;
        
        
        // 更新UILabel内容
        NSString* currentContent= [content substringWithRange:rangeOfPages[0]];
//        NSLog(@"-----pageString   -----end text:\n%@\n\n",currentContent);
        self.pagingContent=currentContent;
        unsigned long encode = CFStringConvertEncodingToNSStringEncoding(suitableEncoding);
        int length= [currentContent lengthOfBytesUsingEncoding:encode];
        if (rangeOfPages) {
            free(rangeOfPages);
            rangeOfPages=nil;
        }
        //NSLog(@"time interval--pageString ---6--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
        return length;
    }
    
}

#pragma mark - view control
- (void)viewDidLoad
{
    [ [ UIApplication sharedApplication ] setIdleTimerDisabled:YES ] ;
    
    preOffset=0;
    currentOffset=0;
    nextOffset=0;
    currentLength=0;
    maxLength=0;
    fileLength=1; //初始化1，显示页数%时候，做除数，所以不为0
    currentPageIndex=0;
    isBottomMenuShowing=NO;
    isSimpleViewShowing=NO;
    suitableEncoding=INT32_MAX;
    
     NSUserDefaults* def=[NSUserDefaults standardUserDefaults];    
    fontSize=[def integerForKey:UDF_FONT_SIZE];
    
    _vPageBg=[[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, SCREEN_HEIGHT)];
    
    lbContent=[[UILabel alloc]initWithFrame:CGRectMake(15, 40, 285, SCREEN_HEIGHT-80) ];
    pageInfoLabel=[[UILabel alloc]initWithFrame:IS_IPAD?CGRectMake(92, 949, 89, 21):CGRectMake(116, SCREEN_HEIGHT-36, 250, 21)];
    lbContent.numberOfLines = 0;
    lbContent.font=[UIFont systemFontOfSize:fontSize];
    

    [self updateThemeByTheme:[def stringForKey:UDF_THEME]];
    
    [_vPageBg addSubview:lbContent];
    
    pageInfoLabel.font=[UIFont systemFontOfSize:10];
    pageInfoLabel.backgroundColor=[UIColor clearColor];
    pageInfoLabel.textColor=[UIColor grayColor];
    
    
    self.lbContentAdapter=(UILabel*)[VIewUtil clone:self.lbContent];
    pageInfoManage=[[PageInfoManage alloc]init];
    

    
    NSArray *ps = [_filePath componentsSeparatedByString:@"/"];
    if (ps.count>0) {
        self.fileName=[ps objectAtIndex:ps.count-1];
    }else{
        NSLog(@"error !!!! fileName is nil");
        self.fileName=@"";
    }
    
//    self.filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"笑傲江湖-utf8.txt"];
    
    fileLength= [self getFileSize:_filePath];
    if (fileLength==0) {
        fileLength=1;
        NSLog(@"file is empty!!!!");
    }
    
    //--------
    
    [self checkEncoding:_filePath];
    BookInfo* bi=[[BookInfoManage share]getBookInfo:_fileName];
    if (bi) {
        [self jumpToOffsetWithLeaves:bi.lastOffset];
    }else{
        [self jumpToOffsetWithLeaves:0];
    }
    
    
    


    
    
    
    /*
    // 从文件里加载文本串
    self.text=nil;

    int tmpLength=MAX_CHARACTER_LENGHT;

    while (!self.text) {
        self.text=[self loadStringFrom:0 length:tmpLength];
        NSLog(@"tmpLength:%d",tmpLength);
        if (!self.text) {
            tmpLength--;
        }
    }
    [self updateOffsetInfo];
    [self updatePageContent];
    */
    [super viewDidLoad];
    [self.view addSubview:pageInfoLabel];
    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.barStyle = UIBarStyleBlackTranslucent;
    self.wantsFullScreenLayout=YES;
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];

    
    UIBarButtonItem *flipButton = [[UIBarButtonItem alloc]
                                   initWithTitle:@"返回"
                                   style:UIBarButtonItemStyleBordered
                                   target:self
                                   action:@selector(goBack:)];
    self.navigationItem.leftBarButtonItem = flipButton;
    self.navigationItem.title=_fileName;
    
    self.vCover=[[[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, SCREEN_HEIGHT)]autorelease];
    _vCover.backgroundColor=[UIColor blackColor];    
    [_vCover setUserInteractionEnabled:NO];
    _vCover.alpha=[def floatForKey:UDF_ALPHA];
    UIWindow* mainWindow = [[UIApplication sharedApplication] keyWindow];
    [mainWindow addSubview: _vCover];
    
}
-(void)updateThemeByTheme:(NSString*)theme{
    BookTheme* bt=[[BookThemeManage share]getBookThemeByTheme:theme];
    _vPageBg.backgroundColor=bt.colVBg;
    lbContent.textColor=bt.colFont;
    lbContent.backgroundColor=bt.colLbContnetBg;
}

-(void)goBack:(id)sender{
    [_vCover removeFromSuperview];    
    [self dismissModalViewControllerAnimated:YES];
}

-(void)jumpToOffsetWithLeaves:(long long)offset{
    [self jumpToOffset:offset];
    [self updatePageInfoWithCurrentOffset:currentOffset];
    [leavesView reloadData];
    leavesView.currentPageIndex=pageInfoManage.currentPI.pageIndex;
    currentPageIndex=leavesView.currentPageIndex;
    [self updatePageInfoContent];
}

//get sutiable offset when jump

-(NSString*)jumpToOffset:(long long) fromOffset{
    NSString* content=nil;
    int tmpLength=MAX_CHARACTER_LENGHT;
    while (!content  ) {
        int tmpCount=0;
        while (!content  && tmpCount<READ_TRY_COUNT_MAX) {
            content=[self loadStringFrom:fromOffset length:tmpLength];
//            NSLog(@"tmpIndex:%lld,tmpLength:%d,tmpCount:%d",fromIndex,tmpLength,tmpCount);
            if (!content) {
                tmpCount++;
                tmpLength--;
            }
        }
        if (!content) {
             fromOffset++;
        }
    
    }
    currentOffset=fromOffset;
    NSLog(@"jumpToOffset---:%d",currentOffset);
    return content;
}

-(void)updateOffsetInfo{
    int currentPageLength= [self pageString:self.text isNext:YES];
    preOffset=0;
    //这里不能+1是因为currentOffset从0开始
    nextOffset=currentOffset+ currentPageLength;
    NSLog(@"--currentPageLength:%d,preOffset:%d,currentOffset%d,nextOffset:%d",currentPageLength,preOffset,currentOffset,nextOffset);
}

-(void)updatePageContent{
    // 显示当前页面进度信息，格式为："8/100"
    lbContent.text = _pagingContent;
    
}
-(void)updatePageInfoContent{
    PageInfo* pi=[pageInfoManage getPageInfoAtIndex:currentPageIndex];
    if (!pi || !pi.isValid) {
        [self updatePageInfoWithPaging:currentPageIndex];
        pi= [pageInfoManage getPageInfoAtIndex:currentPageIndex];
    }
    NSDateFormatter * dateFormatter = [[[NSDateFormatter alloc] init]autorelease];
    [dateFormatter setDateFormat:@"h:MM:ss a"];    
    NSString* dataStr = [dateFormatter stringFromDate:[NSDate date]];
    
    
    pageInfoLabel.text = [NSString stringWithFormat:@"%0.2f %@   %@", (double)pi.dataOffset/fileLength*100,@"%",dataStr];
    
    
    
    [[BookInfoManage share]updateBookInfo:_fileName offset:pi.dataOffset];
    
}
-(NSString*)loadString{
    return [self loadStringFrom:0 length:MAX_CHARACTER_LENGHT];
}
-(long long)getFileSize:(NSString*)filePath{
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:0];
    
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    long long fileSize = [fileSizeNumber longLongValue];
    NSLog(@"fileSize:%lld",fileSize);
    return fileSize;
}

-(NSString*)loadStringFrom:(long long)index length:(int)length{

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];
    [fileHandle seekToFileOffset:index];
    NSData *responseData = [fileHandle readDataOfLength:length];
    
    //GBK encoding
//    unsigned long encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
    NSString *mTxt =nil;
    if (suitableEncoding!=INT32_MAX) {
        unsigned long encode = CFStringConvertEncodingToNSStringEncoding(suitableEncoding);
        mTxt = [[[NSString alloc] initWithData:responseData encoding:encode]autorelease];
    } 
    return mTxt;
}

-(void)checkEncoding:(NSString*)fp{
    
    
    CFStringEncoding allEncodings[]={
        kCFStringEncodingUTF8 ,
        kCFStringEncodingGB_18030_2000,
        kCFStringEncodingUTF16 ,
        kCFStringEncodingUTF16BE ,
        kCFStringEncodingUTF16LE ,
        kCFStringEncodingUTF32 ,
        kCFStringEncodingUTF32BE ,
        kCFStringEncodingUTF32LE,
        
        
        kCFStringEncodingWindowsLatin1,
        kCFStringEncodingISOLatin1 ,
        kCFStringEncodingNextStepLatin,
        kCFStringEncodingASCII ,
        kCFStringEncodingUnicode ,
        kCFStringEncodingNonLossyASCII ,
        
    };

    NSLog(@"fp:%@",fp);
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fp];
    [fileHandle seekToFileOffset:0];
    NSData *responseData = nil;
    unsigned long encode=0;
    NSString *mTxt =nil;
    BOOL isFound=NO;

    
    for (int i=0; (i<ARRAR_COUNT(allEncodings))&& !isFound; i++) {
     encode = CFStringConvertEncodingToNSStringEncoding(allEncodings[i]);
        int tmpLength=10;
        for (int j=0; (j<6) && !isFound; j++) {
            [fileHandle seekToFileOffset:0];
            responseData= [fileHandle readDataOfLength:tmpLength];
            NSLog(@"finding suitableEncoding:%lx,tmpLength:%d",allEncodings[i],tmpLength);            
            mTxt = [[[NSString alloc] initWithData:responseData encoding:encode]autorelease];
            if (![StringUtil isNilOrEmpty:mTxt]) {
                suitableEncoding=allEncodings[i];
                NSLog(@"responseData:%@",responseData);
                isFound=YES;
                NSLog(@"suitableEncoding:%lx,i:%d\nmTxt:%@",suitableEncoding,i,mTxt);
                break;
            }else{
                tmpLength--;
            }
        }        
    }

    
}

-(NSString*)getBookMarkName{
    PageInfo* pi= [pageInfoManage getPageInfoAtIndex:currentPageIndex];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];    
    NSData *responseData = nil;

    NSString *mTxt =nil;
    int tmpLength=80;
    unsigned long encode = CFStringConvertEncodingToNSStringEncoding(suitableEncoding);
    for (int j=0; (j<6); j++) {
        [fileHandle seekToFileOffset:pi.dataOffset];
        responseData= [fileHandle readDataOfLength:tmpLength];
        mTxt = [[[NSString alloc] initWithData:responseData encoding:encode]autorelease];
        if (![StringUtil isNilOrEmpty:mTxt]) {
            return mTxt;
        }else{
            tmpLength--;
        }
    }
    return @"";

}


#pragma mark -
- (IBAction)jumpTo:(id)sender {
    int offset=self.tvJumpTo.text.intValue;
    self.text= [self jumpToOffset:offset* fileLength/100];
    [self updateOffsetInfo];
    [self updatePageContent];
    [self updatePageInfoContent];
    
}



// 上一页
- (IBAction)actionPrevious:(id)sender {
//    //NSTimeInterval timeStart=[[[[NSDate alloc]init]autorelease]timeIntervalSince1970];
    // 从文件里加载文本串
    NSLog(@"---1--preOffset:%d,currentOffset:%d,nextOffset:%d",preOffset,currentOffset,nextOffset);
    if (currentOffset<=0) {
         NSLog(@"++++++++++++++\n it is the first page already !!!\n");
        return;
    }
    int tmpLength=(currentOffset<MAX_CHARACTER_LENGHT)?currentOffset:MAX_CHARACTER_LENGHT;
    self.text=nil;
    while (!self.text
           && tmpLength>=0) {
        self.text=[self loadStringFrom:currentOffset-tmpLength length:tmpLength];
//        NSLog(@"tmpLength:%d",tmpLength);
        if (!self.text) {
            tmpLength--;
        }
    }
    if (tmpLength!=0) {
        int currentPageLength= [self pageString:self.text isNext:NO];
        nextOffset=currentOffset;
//        if (currentPageLength>0) {
//            currentOffset=currentOffset-currentPageLength;
//        }else if(currentPageLength==e_can_show_one_page){
//            currentOffset=0;
//        }
        currentOffset=currentOffset-currentPageLength;
        NSLog(@"++currentPageLength:%d,preOffset:%d,currentOffset:%d,nextOffset:%d",currentPageLength,preOffset,currentOffset,nextOffset);
    }else{
        currentOffset=0;
        NSLog(@"++++++++++++++\n it is the first page already !!!\n");
    }
    
   [self updatePageContent];
    [self updatePageInfoContent];
//    //NSLog(@"time interval--viewDidLoad ---4--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);

    
}

////////////////////////////////////////////////////////////////////////////////////////
// 下一页
- (IBAction)actionNext:(id)sender {
//    //NSTimeInterval timeStart=[[[[NSDate alloc]init]autorelease]timeIntervalSince1970];
    if (currentOffset==nextOffset
        && currentOffset!=0) {
         NSLog(@"++++++++++++++\n it is the last page already !!!!\n");
        return;
    }
    // 从文件里加载文本串
    self.text=nil;
    
    int tmpLength=MAX_CHARACTER_LENGHT;    
    while (!self.text) {
        self.text=[self loadStringFrom:nextOffset length:tmpLength];
//        NSLog(@"tmpLength:%d",tmpLength);
        if (!self.text) {
            tmpLength--;
        }
    }
    if (tmpLength!=0) {
        int currentPageLength= [self pageString:self.text isNext:YES];
        preOffset=currentOffset;
        currentOffset=nextOffset;
        if (currentPageLength>0) {
            nextOffset+=currentPageLength;
        }

        NSLog(@"++currentPageLength:%d,preOffset:%d,currentOffset:%d,nextOffset:%d",currentPageLength,preOffset,currentOffset,nextOffset);
    }else{
        currentOffset=0;
        NSLog(@"++preOffset:%d,currentOffset:%d,nextOffset:%d",preOffset,currentOffset,nextOffset);
        NSLog(@"++++++++++++++\n it is the last page already !!!\n");
    }
    [self updatePageContent];
    [self updatePageInfoContent];
//    //NSLog(@"time interval--viewDidLoad ---4--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
}
#pragma mark leaves
- (NSUInteger) numberOfPagesInLeavesView:(LeavesView*)leavelsView {
	return INT32_MAX;
}
- (BOOL) hasPrevPage {
//    PageInfoScale* pis= [pageInfoManage getPageInfoScale];
//    return pis.minPageInfo.dataOffset>0;
    PageInfo* pi= [pageInfoManage getPageInfoByIndex:currentPageIndex];
    if (pi) {
        return pi.dataOffset>0;
    }else{
        PageInfoScale* pis= [pageInfoManage getPageInfoScale];
        return pis.minPageInfo.dataOffset>0;
    }
    
    
//    PageInfoScale* pis= [pageInfoManage getPageInfoScale];
//    return pis.minPageInfo.dataOffset>0;
}

- (BOOL) hasNextPage {
    //TODO
//	PageInfoScale* pis= [pageInfoManage getPageInfoScale];
//    return pis.maxPageInfo.dataOffset+pis.maxPageInfo.pageLength<fileLength;
    
    PageInfo* pi= [pageInfoManage getPageInfoByIndex:currentPageIndex];
    if (pi) {
        return pi.dataOffset+pi.pageLength<fileLength;
    } else {
        PageInfoScale* pis= [pageInfoManage getPageInfoScale];
        return pis.maxPageInfo.dataOffset+pis.maxPageInfo.pageLength<fileLength;
    }
    
}
- (void) renderPageAtIndex:(NSUInteger)index inContext:(CGContextRef)ctx {
    PageInfo* pi= [pageInfoManage getPageInfoAtIndex:index];
    NSLog(@"\nrenderPageAtIndex----pi:%@",pi);
    if (!pi || !pi.isValid) {
        [self updatePageInfoWithPaging:index];
        pi= [pageInfoManage getPageInfoAtIndex:index];
        NSLog(@"\nrenderPageAtIndex--2--pi:%@",pi);
    }
    
    UIView* view=pi.pageView;
    UIImage *image = [self imageWithView:view];
	CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
	CGAffineTransform transform = aspectFit(imageRect,
											CGContextGetClipBoundingBox(ctx));
	CGContextConcatCTM(ctx, transform);
	CGContextDrawImage(ctx, imageRect, [image CGImage]);
}
// called when the user touches up on the left or right side of the page, or finishes dragging the page
- (void) leavesView:(LeavesView *)leavesView willTurnToPageAtIndex:(NSUInteger)pageIndex{
    
}

// called when the page-turn animation (following a touch-up or drag) completes
- (void) leavesView:(LeavesView *)leavesView didTurnToPageAtIndex:(NSUInteger)pageIndex{
    currentPageIndex=pageIndex;
    [self updatePageInfoContent];
}

#pragma mark -
//一般是初次进入，或是jump后使用更新
//根据当前offset来更新pageInfo
-(void)updatePageInfoWithCurrentOffset:(int)offset{
    
    pageInfoManage.currentPI.pageIndex=2;
    pageInfoManage.currentPI.dataOffset=currentOffset;
    [self viewWithPI:pageInfoManage.currentPI isNext:YES];
    NSLog(@"currentPageLength---currentPI--:%d",pageInfoManage.currentPI.pageLength);
    //NSTimeInterval timeStart=[[[[NSDate alloc]init]autorelease]timeIntervalSince1970];
    if (pageInfoManage.currentPI.dataOffset>0) {
        pageInfoManage.currentPI_M.pageIndex=pageInfoManage.currentPI.pageIndex-1;
        //这里先设置结尾的offset
        pageInfoManage.currentPI_M.dataOffset=pageInfoManage.currentPI.dataOffset;
        //在这里将结尾offset换成开头offset
        [self viewWithPI:pageInfoManage.currentPI_M isNext:NO];
        NSLog(@"currentPageLength---currentPI_M--:%@",pageInfoManage.currentPI_M);
        //NSLog(@"time interval--viewDidLoad ---4--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    }else{
        pageInfoManage.currentPI_M.isValid=NO;
    }
    
    if (pageInfoManage.currentPI_M.dataOffset>0) {
        pageInfoManage.currentPI_MM.pageIndex=pageInfoManage.currentPI_M.pageIndex-1;
        //这里先设置结尾的offset
        pageInfoManage.currentPI_MM.dataOffset=pageInfoManage.currentPI_M.dataOffset;
        //在这里将结尾offset换成开头offset
        [self viewWithPI:pageInfoManage.currentPI_MM isNext:NO];
        NSLog(@"currentPageLength---currentPI_MM--:%d",pageInfoManage.currentPI_MM.pageLength);
    }else{
        pageInfoManage.currentPI_MM.isValid=NO;
    }
    
    
    int tmpOffset=pageInfoManage.currentPI.dataOffset+pageInfoManage.currentPI.pageLength;
    if (tmpOffset<fileLength) {
        pageInfoManage.currentPI_A.pageIndex=pageInfoManage.currentPI.pageIndex+1;
        pageInfoManage.currentPI_A.dataOffset=tmpOffset;
        [self viewWithPI:pageInfoManage.currentPI_A isNext:YES];
        NSLog(@"currentPageLength---currentPI_A--:%d",pageInfoManage.currentPI_A.pageLength);
        
        tmpOffset=pageInfoManage.currentPI_A.dataOffset+pageInfoManage.currentPI_A.pageLength;
        if (tmpOffset<fileLength) {
            pageInfoManage.currentPI_AA.pageIndex=pageInfoManage.currentPI_A.pageIndex+1;
            pageInfoManage.currentPI_AA.dataOffset=pageInfoManage.currentPI_A.dataOffset+pageInfoManage.currentPI_A.pageLength;
            [self viewWithPI:pageInfoManage.currentPI_AA isNext:YES];
            NSLog(@"currentPageLength---currentPI_AA--:%d",pageInfoManage.currentPI_AA.pageLength);
        } else {
            pageInfoManage.currentPI_AA.isValid=NO;
        }        
    }else{
        pageInfoManage.currentPI_A.isValid=NO;
        pageInfoManage.currentPI_AA.isValid=NO;
    }
}
//自动翻页时候更新
-(void)updatePageInfoWithPaging:(int)index{
    NSLog(@"updatePageInfoWithPaging---start--currentPageIndex:%d,index:%d-pageInfoManage:%@",currentPageIndex,index,pageInfoManage);
    PageInfoScale* pis= [pageInfoManage getPageInfoScale];
    if (pis.maxPageInfo.pageIndex<index) {
        //向后翻页
        
        PageInfoType validepit=0;//向后查询，得到最后一个valide的tag

        
        pageInfoManage.currentPI_MM.isValid=NO;
        //先逐层保存传递旧值
        pageInfoManage.currentPI_M=pageInfoManage.currentPI;
        validepit=e_current;
        if (pageInfoManage.currentPI_A.isValid) {
            pageInfoManage.currentPI=pageInfoManage.currentPI_A;
            validepit=e_current_a;
            if (pageInfoManage.currentPI_AA.isValid) {
                pageInfoManage.currentPI_A=pageInfoManage.currentPI_AA;
                validepit=e_current_aa;
            }
        }
        
        
        
        int tmpOffset=0;
        int offset=0;
        switch (validepit) {
            case e_current:
                pageInfoManage.currentPI=[[PageInfo alloc]init];                
                tmpOffset=pageInfoManage.currentPI_M.dataOffset+pageInfoManage.currentPI_M.pageLength;
                pageInfoManage.currentPI.pageIndex=pageInfoManage.currentPI_M.pageIndex+1;
                pageInfoManage.currentPI.dataOffset=tmpOffset;
                offset=[self viewWithPI:pageInfoManage.currentPI isNext:YES];
                if (offset>0) {
                    pageInfoManage.currentPI.isValid=YES;
                }else{
                    pageInfoManage.currentPI.isValid=NO;
                    break;
                }
//                NSLog(@"view--2:%@",pageInfoManage.currentPI);
            case e_current_a:
                pageInfoManage.currentPI_A=[[PageInfo alloc]init];
                pageInfoManage.currentPI_A.isValid=YES;
                tmpOffset=pageInfoManage.currentPI.dataOffset+pageInfoManage.currentPI.pageLength;
                pageInfoManage.currentPI_A.pageIndex=pageInfoManage.currentPI.pageIndex+1;
                pageInfoManage.currentPI_A.dataOffset=tmpOffset;
                offset=[self viewWithPI:pageInfoManage.currentPI_A isNext:YES];
                if (offset>0) {
                    pageInfoManage.currentPI_A.isValid=YES;
                }else{
                    pageInfoManage.currentPI_A.isValid=NO;
                    break;
                }
//                NSLog(@"view--3:%@",pageInfoManage.currentPI_A);
            case e_current_aa:
                pageInfoManage.currentPI_AA=[[PageInfo alloc]init];
                pageInfoManage.currentPI_AA.isValid=YES;
                tmpOffset=pageInfoManage.currentPI_A.dataOffset+pageInfoManage.currentPI_A.pageLength;
                pageInfoManage.currentPI_AA.pageIndex=pageInfoManage.currentPI_A.pageIndex+1;
                pageInfoManage.currentPI_AA.dataOffset=tmpOffset;
                offset=[self viewWithPI:pageInfoManage.currentPI_AA isNext:YES];
                if (offset>0) {
                    pageInfoManage.currentPI_AA.isValid=YES;
                }else{
                    pageInfoManage.currentPI_AA.isValid=NO;
                    break;
                }
//                NSLog(@"view--4:%@",pageInfoManage.currentPI_AA);
            default:
                break;
        }

        
        
        
        
    } else if(pis.minPageInfo.pageIndex>index){
        //向前翻页
        PageInfoType validepit=0;//向前查询，得到最头一个valide的tag
        
        
        pageInfoManage.currentPI_AA.isValid=NO;
        //先逐层保存传递旧值
        pageInfoManage.currentPI_A=pageInfoManage.currentPI;
        validepit=e_current;
        if (pageInfoManage.currentPI_M.isValid) {
            pageInfoManage.currentPI=pageInfoManage.currentPI_M;
            validepit=e_current_m;
            if (pageInfoManage.currentPI_MM.isValid) {
                pageInfoManage.currentPI_M=pageInfoManage.currentPI_MM;
                validepit=e_current_mm;
            }
        }
        
        
        
        int tmpOffset=0;
        int offset=0;
        switch (validepit) {
            case e_current:
                pageInfoManage.currentPI=[[PageInfo alloc]init];
                pageInfoManage.currentPI.isValid=YES;
                tmpOffset=pageInfoManage.currentPI_A.dataOffset;
                pageInfoManage.currentPI.pageIndex=pageInfoManage.currentPI_A.pageIndex-1;
                pageInfoManage.currentPI.dataOffset=tmpOffset;
                offset= [self viewWithPI:pageInfoManage.currentPI isNext:NO];
                if (offset>0) {
                    pageInfoManage.currentPI.isValid=YES;
                }else{
                    pageInfoManage.currentPI.isValid=NO;
                    break;
                }
//                NSLog(@"view--2:%@",pageInfoManage.currentPI);
            case e_current_m:
                pageInfoManage.currentPI_M=[[PageInfo alloc]init];
                pageInfoManage.currentPI_M.isValid=YES;
                tmpOffset=pageInfoManage.currentPI.dataOffset;
                pageInfoManage.currentPI_M.pageIndex=pageInfoManage.currentPI.pageIndex-1;
                pageInfoManage.currentPI_M.dataOffset=tmpOffset;
                offset=[self viewWithPI:pageInfoManage.currentPI_M isNext:NO];
                if (offset>0) {
                    pageInfoManage.currentPI_M.isValid=YES;
                }else{
                    pageInfoManage.currentPI_M.isValid=NO;
                    break;
                }
//                NSLog(@"view--3:%@",pageInfoManage.currentPI_M);
            case e_current_mm:
                pageInfoManage.currentPI_MM=[[PageInfo alloc]init];
                pageInfoManage.currentPI_MM.isValid=YES;
                tmpOffset=pageInfoManage.currentPI_M.dataOffset;
                pageInfoManage.currentPI_MM.pageIndex=pageInfoManage.currentPI_M.pageIndex-1;
                pageInfoManage.currentPI_MM.dataOffset=tmpOffset;
                offset=[self viewWithPI:pageInfoManage.currentPI_MM isNext:NO];
                if (offset>0) {
                    pageInfoManage.currentPI_MM.isValid=YES;
                }else{
                    pageInfoManage.currentPI_MM.isValid=NO;
                    break;
                }
//                NSLog(@"view--4:%@",pageInfoManage.currentPI_MM);
            default:
                break;
        }
        
        

    }
    NSLog(@"updatePageInfoWithPaging---end- currentPageIndex:%d,index:%d--pageInfoManage:%@",currentPageIndex,index,pageInfoManage);
}
-(int)viewWithPI:(PageInfo*)pi  isNext:(BOOL)isNext{
    // 从文件里加载文本串
    //NSTimeInterval timeStart=[[[[NSDate alloc]init]autorelease]timeIntervalSince1970];

    NSString* txt=nil;
    int tmpLength=0;
    
    if (isNext) {
        tmpLength=MAX_CHARACTER_LENGHT;
    } else {
        tmpLength=(pi.dataOffset<MAX_CHARACTER_LENGHT)?pi.dataOffset:MAX_CHARACTER_LENGHT;
    }
    NSLog(@"tmpLength--1:%d",tmpLength);
    //NSLog(@"time interval--3--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    while (!txt && tmpLength>=0) {
        txt=[self loadStringFrom:(isNext?pi.dataOffset:pi.dataOffset-tmpLength) length:tmpLength];
        NSLog(@"tmpLength:%d",tmpLength);
        if (!txt) {
            tmpLength--;
        }
    }
    //NSLog(@"time interval--2--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
   int currentPageLength= [self pageString:txt isNext:isNext];
    //NSLog(@"time interval--21--isNext:%d--:%lf",isNext,[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    [self updatePageContent];
    //NSLog(@"time interval--22--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    pi.pageView=[VIewUtil clone:_vPageBg];
    //NSLog(@"time interval--23--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    pi.pageLength=currentPageLength;
    pi.isValid=YES;
    if (!isNext) {
        pi.dataOffset=pi.dataOffset-currentPageLength;
    }
    //NSLog(@"time interval--1--:%lf",[[[[NSDate alloc]init]autorelease]timeIntervalSince1970]-timeStart);
    return currentPageLength;
}


-(void)updatePageView{
    PageInfo* pi= [pageInfoManage getPageInfoAtIndex:currentPageIndex];
    long long offset=pi.dataOffset;
    [self jumpToOffsetWithLeaves:offset];
}

- (UIImage *) imageWithView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}


- (void)dealloc {
    [lbContent release];
    [pageInfoLabel release];
    [_tvJumpTo release];
    [pageInfoManage release];
    [_lbContentAdapter release];
    
    [ [ UIApplication sharedApplication ] setIdleTimerDisabled:NO ] ;
    [super dealloc];
}
#pragma mark menu

#define INDEX_TOOL 0
#define INDEX_JUMP 1111
#define INDEX_SETTING 1

#define TAG_MENU_MAIN 301
#define TAG_MENU_SEGMENT 302
#define TAG_MENU_SEGMENT_TOOL 3021
#define TAG_MENU_SEGMENT_SET 3022


#define TAG_MENU_CONTENT 303

#define TAG_MENU_VIEW_TOOL 304
#define TAG_MENU_VIEW_TOOL_BT_CHAPTER 3041
#define TAG_MENU_VIEW_TOOL_BT_ADD_BOOKMARK 3042
#define TAG_MENU_VIEW_TOOL_BT_BOOKMARK_MANAGE 3043
#define TAG_MENU_VIEW_TOOL_BT_JUMP 3044

#define TAG_MENU_VIEW_JUMP 305
#define TAG_MENU_VIEW_JUMP_PRE_CHARPTER 3051
#define TAG_MENU_VIEW_JUMP_NEXT_CHARPTER 3052

#define TAG_MENU_VIEW_SETTING 306
#define TAG_MENU_VIEW_SETTING_THEME 3061
#define TAG_MENU_VIEW_SETTING_FONT 3062
#define TAG_MENU_VIEW_SETTING_ENCODING 3063
#define TAG_MENU_VIEW_SETTING_SET 3064
#define TAG_MENU_VIEW_SETTING_HELP 3065
#define TAG_MENU_VIEW_SETTING_LIGHT 3066




#define TAG_SIMPLE_VIEW_OK 501
#define TAG_SIMPLE_VIEW_CANCEL 502


#define TAG_SIMPLE_VIEW_JUMP 601
#define TAG_SIMPLE_VIEW_JUMP_PER_PREFIX_DOT 6011
#define TAG_SIMPLE_VIEW_JUMP_PER_SUFFIX_DOT 6012
#define TAG_SIMPLE_VIEW_JUMP_SLIDE 6013

#define TAG_SIMPLE_VIEW_FONT 602
#define TAG_SIMPLE_VIEW_FONT_SLIDE 6021

#define TAG_SIMPLE_VIEW_THEME 603
#define TAG_SIMPLE_VIEW_THEME_BLACK THEME_BLACK //6031
#define TAG_SIMPLE_VIEW_THEME_WHITE THEME_WHITE //6032
#define TAG_SIMPLE_VIEW_THEME_CHECK 603001

#define TAG_SIMPLE_VIEW_LIGHT 604
#define TAG_SIMPLE_VIEW_LIGHT_SLIDE 6041


#pragma mark -
-(UIView*)findViewWithTag:(NSArray*)views tag:(int)tag{
    for (UIView* v in views) {
        if (v.tag==tag) {
            return v;
        }
    }
    return nil;
}

-(BOOL)handlerTouched{
    NSLog(@"handlerTouched---");
    BOOL isYes=NO;
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isYes=YES;
    }
    if (isSimpleViewShowing) {
        [self showJumpView:NO];
        [self showFontView:NO];
        [self showThemeView:NO];
        [self showLightView:NO];
        isYes=YES;
    }
    return isYes;
}
-(void)handlerTouchedMidPage{
    NSLog(@"handlerTouchedMidPage---");
    
    if (!isBottomMenuShowing) {
        [self showBottomMenu:YES];
    }
}


- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated permanent:(BOOL)permanent withStatusbar:(BOOL)withStatusbar{
    
  
    // Status Bar
    if (withStatusbar) {
        [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animated?UIStatusBarAnimationFade:UIStatusBarAnimationNone];
    }
    [self.navigationController setNavigationBarHidden:hidden animated:YES];


	// Animate
    if (animated) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.35];
    }
	if (animated) {
        [UIView commitAnimations];
    }

	
}


-(void)showBottomMenu:(BOOL)toShow {
    [self setControlsHidden:!toShow animated:YES permanent:YES withStatusbar:YES];
    if (!_vMenu) {
        //得到所有的menu并添加事件
        NSArray* views= [[NSBundle mainBundle] loadNibNamed:@"BottomMenu_iphone" owner:self options:nil] ;
        self.vMenu= [self findViewWithTag:views tag:TAG_MENU_MAIN];
        self.vMenuTool= [self findViewWithTag:views tag:TAG_MENU_VIEW_TOOL];
        self.vMenuJump= [self findViewWithTag:views tag:TAG_MENU_VIEW_JUMP];
        self.vMenuSetting= [self findViewWithTag:views tag:TAG_MENU_VIEW_SETTING];
        [[self.vMenu viewWithTag:TAG_MENU_CONTENT] addSubview:_vMenuTool];
        [self.view addSubview:_vMenu];
        
        
        //add target vMenuTool
        UIButton* btShowJump= (UIButton*)[_vMenuTool viewWithTag:TAG_MENU_VIEW_TOOL_BT_JUMP];
        [btShowJump addTarget:self action:@selector(showJumpView) forControlEvents:UIControlEventTouchUpInside];
        

        UIButton* btAddBookMark= (UIButton*)[_vMenuTool viewWithTag:TAG_MENU_VIEW_TOOL_BT_ADD_BOOKMARK];
        [btAddBookMark addTarget:self action:@selector(addBookMark:) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton* btshowBookMark= (UIButton*)[_vMenuTool viewWithTag:TAG_MENU_VIEW_TOOL_BT_BOOKMARK_MANAGE];
        [btshowBookMark addTarget:self action:@selector(showAllBookMarks:) forControlEvents:UIControlEventTouchUpInside];
        
        //add target vMenuJump
        //add target vMenuSetting
        UIButton* btShowTheme= (UIButton*)[_vMenuSetting viewWithTag:TAG_MENU_VIEW_SETTING_THEME];
        [btShowTheme addTarget:self action:@selector(showThemeView) forControlEvents:UIControlEventTouchUpInside];
        
        
        UIButton* btShowFont= (UIButton*)[_vMenuSetting viewWithTag:TAG_MENU_VIEW_SETTING_FONT];
        [btShowFont addTarget:self action:@selector(showFontView) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton* btShowLight= (UIButton*)[_vMenuSetting viewWithTag:TAG_MENU_VIEW_SETTING_LIGHT];
        [btShowLight addTarget:self action:@selector(showLightView) forControlEvents:UIControlEventTouchUpInside];
        
        
        //=============

        
        
        self.btMenuTool=(UIButton*)[self.vMenu viewWithTag:TAG_MENU_SEGMENT_TOOL];
        self.btMenuSet=(UIButton*)[self.vMenu viewWithTag:TAG_MENU_SEGMENT_SET];        
        [_btMenuTool setBackgroundImage:[UIImage imageNamed:@"menu_segment_bg_selected"] forState:UIControlStateSelected];
//        [_btMenuTool setBackgroundImage:[UIImage imageNamed:@"menu_segment_bg_selected"] forState:UIControlStateHighlighted];
        [_btMenuTool setBackgroundImage:[UIImage imageNamed:@"menu_segment_bg"] forState:UIControlStateNormal];
        
        [_btMenuSet setBackgroundImage:[UIImage imageNamed:@"menu_segment_bg_selected"] forState:UIControlStateSelected];
//        [_btMenuSet setBackgroundImage:[UIImage imageNamed:@"menu_segment_bg_selected"] forState:UIControlStateHighlighted];
        [_btMenuSet setBackgroundImage:[UIImage imageNamed:@"menu_segment_bg"] forState:UIControlStateNormal];
        
        [_btMenuTool addTarget:self action:@selector(changeMenuButton:) forControlEvents:UIControlEventTouchUpInside];        
        [_btMenuSet addTarget:self action:@selector(changeMenuButton:) forControlEvents:UIControlEventTouchUpInside];
        [self resetAllMenuButton];
        _btMenuTool.selected=YES;
//        _btMenuTool.enabled=NO;
        
    }
    
    CGRect frame=self.view.frame;
    if (toShow) {
        _vMenu.frame=CGRectMake(0, frame.size.height, _vMenu.frame.size.width, _vMenu.frame.size.height);
    }else{
        _vMenu.frame=CGRectMake(0, frame.size.height-_vMenu.frame.size.height, _vMenu.frame.size.width, _vMenu.frame.size.height);
    }
    
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelay:0];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    
    if (toShow) {
        _vMenu.frame=CGRectMake(0, frame.size.height-_vMenu.frame.size.height, _vMenu.frame.size.width, _vMenu.frame.size.height);
    }else{
         _vMenu.frame=CGRectMake(0, frame.size.height, _vMenu.frame.size.width, _vMenu.frame.size.height);
    }

    [UIView commitAnimations];
    isBottomMenuShowing=toShow;
}
-(void)resetAllMenuButton{
    _btMenuSet.selected=NO;
    _btMenuTool.selected=NO;
//    _btMenuSet.enabled=YES;
//    _btMenuTool.enabled=YES;
}
-(void)changeMenuButton:(UIButton*)sender{
    [self resetAllMenuButton];
//    sender.enabled=NO;
    sender.selected=YES;
    UIView* vContent=[self.vMenu viewWithTag:TAG_MENU_CONTENT] ;
    [VIewUtil removeAllSubviews:vContent];
    switch (sender.tag) {
        case TAG_MENU_SEGMENT_TOOL:
        {
            [vContent addSubview:_vMenuTool];
        }
            break;
        case TAG_MENU_SEGMENT_SET:
        {
            [vContent addSubview:_vMenuSetting];
        }
            break;
    }
    
    
}


-(void)changeMenuSegment:(UISegmentedControl*)sender{
    UIView* vContent=[self.vMenu viewWithTag:TAG_MENU_CONTENT] ;
    [VIewUtil removeAllSubviews:vContent];
    switch (sender.selectedSegmentIndex) {
        case INDEX_TOOL:
        {
            [vContent addSubview:_vMenuTool];
        }
            break;
        case INDEX_JUMP:
        {
            [vContent addSubview:_vMenuJump];
        }
            break;
        case INDEX_SETTING:
        {
            [vContent addSubview:_vMenuSetting];
        }
            break;
    }
}

-(void)showJumpView{
    [self showJumpView:YES];
}

-(void)showJumpView:(BOOL)toShow{
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isBottomMenuShowing=NO;
    }
    if (!self.vJump) {
        NSArray* views= [[NSBundle mainBundle] loadNibNamed:@"BottomMenu_iphone" owner:self options:nil] ;
        self.vJump= [self findViewWithTag:views tag:TAG_SIMPLE_VIEW_JUMP];
        UIButton* btOK=(UIButton*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_OK];
        [btOK addTarget:self action:@selector(jumpOffset:) forControlEvents:UIControlEventTouchUpInside];
        UIButton* btCancel=(UIButton*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_CANCEL];
        [btCancel addTarget:self action:@selector(jumpOffset:) forControlEvents:UIControlEventTouchUpInside];
        
        UISlider* sdJump= (UISlider*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_SLIDE];
        [sdJump addTarget:self action:@selector(changeJumpSlide:) forControlEvents:UIControlEventValueChanged];
        
        
        
        _vJump.layer.cornerRadius = 6;
        _vJump.layer.masksToBounds = YES;
        
    }

    if (toShow) {
        [self updateJumpViewData];
        CGRect frame=self.view.frame;
        _vJump.frame=CGRectMake((frame.size.width-_vJump.frame.size.width)/2, 100, _vJump.frame.size.width, _vJump.frame.size.height);
        [self.view addSubview:_vJump];
        isSimpleViewShowing=YES;
    } else {
        [_vJump removeFromSuperview];
        isSimpleViewShowing=NO;
    }   
    [UIView commitAnimations];
}
-(void)updateJumpViewData{
    UISlider* sdJump= (UISlider*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_SLIDE];
    PageInfo* pi= [pageInfoManage getPageInfoAtIndex:currentPageIndex];
    long long offset=pi.dataOffset;
    UILabel* lbPerPreDot=(UILabel*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_PER_PREFIX_DOT];
    UILabel* lbPerSuffDot=(UILabel*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_PER_SUFFIX_DOT];
   
    lbPerPreDot.text=[NSString stringWithFormat:@"%lld",offset*100/fileLength];
    lbPerSuffDot.text=[NSString stringWithFormat:@"%lld",(offset*10000/fileLength)%100];
    sdJump.value=(((double)offset)/fileLength);
}

-(void)changeJumpSlide:(UISlider*)sender{
    [self jumpToOffsetWithLeaves:(sender.value*fileLength)];
    UILabel* lbPerPreDot=(UILabel*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_PER_PREFIX_DOT];
    UILabel* lbPerSuffDot=(UILabel*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_PER_SUFFIX_DOT];    
    lbPerPreDot.text=[NSString stringWithFormat:@"%2d",(int)(sender.value*100)];
    lbPerSuffDot.text=[NSString stringWithFormat:@"%2d",((int) (sender.value*10000))%100];
}

-(void)jumpOffset:(UIButton*)sender{
    switch (sender.tag) {
        case TAG_SIMPLE_VIEW_OK:
        {
            UILabel* lbPerPreDot=(UILabel*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_PER_PREFIX_DOT];
            UILabel* lbPerSuffDot=(UILabel*)[_vJump viewWithTag:TAG_SIMPLE_VIEW_JUMP_PER_SUFFIX_DOT];
            NSString* offsetValue=[NSString stringWithFormat:@"%@.%@",lbPerPreDot.text,lbPerSuffDot.text];
            float tmpOffset=offsetValue.floatValue;
            if (tmpOffset>=0 && tmpOffset<=100) {
                [self jumpToOffsetWithLeaves:(tmpOffset*fileLength/100)];
            }else{
                NSLog(@"error input page jump value");
            }
            
        }
            break;
        case TAG_SIMPLE_VIEW_CANCEL:
            
            break;
            
        default:
            break;
    }
    [self showJumpView:NO];
}
-(void)showThemeView{
    [self showThemeView:YES];
}
-(void)showThemeView:(BOOL)toShow{
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isBottomMenuShowing=NO;
    }
    if (!self.vTheme) {
        NSArray* views= [[NSBundle mainBundle] loadNibNamed:@"BottomMenu_iphone" owner:self options:nil] ;
        self.vTheme= [self findViewWithTag:views tag:TAG_SIMPLE_VIEW_THEME];
        
        UIButton* btBlack=(UIButton*)[_vTheme viewWithTag:TAG_SIMPLE_VIEW_THEME_BLACK];
        [btBlack addTarget:self action:@selector(changeTheme:) forControlEvents:UIControlEventTouchUpInside];
        UIButton* btWhite=(UIButton*)[_vTheme viewWithTag:TAG_SIMPLE_VIEW_THEME_WHITE];
        [btWhite addTarget:self action:@selector(changeTheme:) forControlEvents:UIControlEventTouchUpInside];

        UIImageView* ivCheck=[[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"check"]]autorelease];
        ivCheck.tag=TAG_SIMPLE_VIEW_THEME_CHECK;
        [_vTheme addSubview:ivCheck];
        _vTheme.layer.cornerRadius = 6;
        _vTheme.layer.masksToBounds = YES;
        
    }
    
    if (toShow) {
        CGRect frame=self.view.frame;
        _vTheme.frame=CGRectMake((frame.size.width-_vTheme.frame.size.width)/2, 100, _vTheme.frame.size.width, _vTheme.frame.size.height);
        [self.view addSubview:_vTheme];
        isSimpleViewShowing=YES;
        [self updateThemeCheck];
        
        
    } else {
        [_vTheme removeFromSuperview];
        isSimpleViewShowing=NO;
    }
    [UIView commitAnimations];
}
-(void)updateThemeCheck{
    UIImageView* ivCheck=(UIImageView*)[_vTheme viewWithTag:TAG_SIMPLE_VIEW_THEME_CHECK];
    
    NSUserDefaults* df=[NSUserDefaults standardUserDefaults];
    NSString* th=[df valueForKey:UDF_THEME];
    UIButton* btTheme=(UIButton*)[_vTheme viewWithTag:th.intValue];
    ivCheck.frame=CGRectMake(btTheme.frame.origin.x+ btTheme.frame.size.width-10, 10,ivCheck.frame.size.width,ivCheck.frame.size.height);
}

-(void)changeTheme:(UIButton*)sender{
    int theme=sender.tag;

    [self updateThemeByTheme:[StringUtil int2String:theme]];
    NSUserDefaults* def=[NSUserDefaults standardUserDefaults];
//    NSLog(@"changeTheme---begin---theme:%@",[def valueForKey:UDF_THEME]);
    [def setValue:[StringUtil int2String:theme] forKey:UDF_THEME];
//    NSLog(@"changeTheme---end---theme:%@",[def valueForKey:UDF_THEME]);
    [self updatePageView];
    [leavesView changeTheme];
    
    [self updateThemeCheck];
}

-(void)showFontView{
    [self showFontView:YES];
}
-(void)showFontView:(BOOL)toShow{
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isBottomMenuShowing=NO;
    }
    if (!self.vFont) {
        NSArray* views= [[NSBundle mainBundle] loadNibNamed:@"BottomMenu_iphone" owner:self options:nil] ;
        self.vFont= [self findViewWithTag:views tag:TAG_SIMPLE_VIEW_FONT];
        UISlider* sdFontSize= (UISlider*)[_vFont viewWithTag:TAG_SIMPLE_VIEW_FONT_SLIDE];
        [sdFontSize addTarget:self action:@selector(changeFontSize:) forControlEvents:UIControlEventValueChanged];
        NSUserDefaults* def=[NSUserDefaults standardUserDefaults];
        sdFontSize.value=SLIDE_VALUE_WITH_FONT([def integerForKey:UDF_FONT_SIZE]);
        
        _vFont.layer.cornerRadius = 6;
        _vFont.layer.masksToBounds = YES;
        
    }
    
    if (toShow) {
        CGRect frame=self.view.frame;
        _vFont.frame=CGRectMake((frame.size.width-_vFont.frame.size.width)/2, 100, _vFont.frame.size.width, _vFont.frame.size.height);
        [self.view addSubview:_vFont];
        isSimpleViewShowing=YES;
    } else {
        [_vFont removeFromSuperview];
        isSimpleViewShowing=NO;
    }
    [UIView commitAnimations];
}
-(void)changeFontSize:(UISlider*)sender{
    fontSize=FONT_VALUE_WITH_SLIDE(sender.value);
    NSLog(@"changeFontSize----fontSize:%d",fontSize);
    NSUserDefaults* def=[NSUserDefaults standardUserDefaults];
    [def setInteger:fontSize forKey:UDF_FONT_SIZE];
    
    
    lbContent.font=[UIFont systemFontOfSize:fontSize];
    
    PageInfo* pi= [pageInfoManage getPageInfoAtIndex:currentPageIndex];
    [self jumpToOffsetWithLeaves:pi.dataOffset];
}
-(void)showLightView{
    [self showLightView:YES];
}
-(void)showLightView:(BOOL)toShow{
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isBottomMenuShowing=NO;
    }
    if (!self.vLight) {
        NSArray* views= [[NSBundle mainBundle] loadNibNamed:@"BottomMenu_iphone" owner:self options:nil] ;
        self.vLight= [self findViewWithTag:views tag:TAG_SIMPLE_VIEW_LIGHT];
        UISlider* sdLight= (UISlider*)[_vLight viewWithTag:TAG_SIMPLE_VIEW_LIGHT_SLIDE];
        [sdLight addTarget:self action:@selector(changeLight:) forControlEvents:UIControlEventValueChanged];
        NSUserDefaults* def=[NSUserDefaults standardUserDefaults];
        sdLight.value=SLIDE_VALUE_WITH_ALPHA([def floatForKey:UDF_ALPHA]);
        
        _vLight.layer.cornerRadius = 6;
        _vLight.layer.masksToBounds = YES;
        
    }
    
    if (toShow) {
        CGRect frame=self.view.frame;
        _vLight.frame=CGRectMake((frame.size.width-_vLight.frame.size.width)/2, 100, _vLight.frame.size.width, _vLight.frame.size.height);
        [self.view addSubview:_vLight];
        isSimpleViewShowing=YES;
    } else {
        [_vLight removeFromSuperview];
        isSimpleViewShowing=NO;
    }
    [UIView commitAnimations];
}
-(void)changeLight:(UISlider*)sender{
    float lightValue=ALPHA_VALUE_WITH_SLIDE(sender.value);
    NSLog(@"changeLight----lightValue:%f",lightValue);
    NSUserDefaults* def=[NSUserDefaults standardUserDefaults];
    [def setFloat:lightValue forKey:UDF_ALPHA];
    _vCover.alpha=lightValue;
}

-(void)addBookMark:(id)sender{
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isBottomMenuShowing=NO;
    }
    NSString* bmName=[self getBookMarkName];
    PageInfo* pi= [pageInfoManage getPageInfoAtIndex:currentPageIndex];
    long long offset=pi.dataOffset;
    
    float percent=(((double)offset)/fileLength);
    [[BookMarkManage share]addBookMarkWithName:_fileName offset:offset percent:percent desc:bmName];
    Alert2(@"添加书签成功");
 
}

-(void)showAllBookMarks:(id)sender{
    if (isBottomMenuShowing) {
        [self showBottomMenu:NO];
        isBottomMenuShowing=NO;
    }
    BookMarkViewController* bmVC=[[[BookMarkViewController alloc]init]autorelease];
    bmVC.bookMarks=(NSMutableArray*) [[BookMarkManage share] getBookMarksWithBookName:_fileName];
    bmVC.readerVC=self;
    [self.navigationController pushViewController:bmVC animated:YES];
    
}


@end
