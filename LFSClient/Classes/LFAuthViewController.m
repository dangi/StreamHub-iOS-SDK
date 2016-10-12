#import "LFAuthViewController.h"
#import "LFHUD.h"
#import <AFNetworking/AFURLRequestSerialization.h>
#import <AFNetworking/AFHTTPRequestOperationManager.h>
#import <Base64/MF_Base64Additions.h>

@interface LFAuthViewController ()<UIWebViewDelegate>
@property(nonatomic,strong) NSString* environment;
@property(nonatomic,strong) NSString* network;
@property(nonatomic,strong) NSString *next;
@property(nonatomic,assign) BOOL verifiedEmail;

@end

static const NSString* kLFSPCookie = @"lfsp-profile";
static const NSString* kCancelPath = @"AuthCanceled";


@implementation LFAuthViewController{
    UIWebView *webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSAssert(self.environment!=nil, @"\n%s Environment id required.\n Use [LFAuthViewController initWithEnvironment: network: next:] for initialize LFAuthViewController",__FUNCTION__);
    NSAssert(self.network!=nil, @"\n%s Network id required.\n Use [LFAuthViewController initWithEnvironment: network: next:] for initialize LFAuthViewController",__FUNCTION__);
    NSAssert(self.next!=nil, @"\n%s Next id required.\n Use [LFAuthViewController initWithEnvironment: network: next:] for initialize LFAuthViewController",__FUNCTION__);
    
    self.view.backgroundColor = [UIColor grayColor];
    
    
    UIButton *cancelButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width-70, 10, 60, 40)];
    [cancelButton addTarget:self action:@selector(cancelAuthSelected) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancelButton];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 50, self.view.frame.size.width, self.view.frame.size.height-50)];
    NSString *encodedURLParamString = [self escapeValueForURLParameter:[NSString stringWithFormat:@"https://identity.%@/%@",self.environment,self.network]];
    NSString *urlString = [NSString stringWithFormat:@"https://identity.%@/%@/pages/auth/engage/?app=%@&next=%@",self.environment,self.network,encodedURLParamString,[self escapeValueForURLParameter:self.next]];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
    webView.delegate=self;
    [self.view addSubview:webView];
    
    
}

-(void)cancelAuthSelected{
    [self failAuth];
}

#pragma mark - Webview delegate

-(void)webViewDidStartLoad:(UIWebView *)webView{
    [LFHUD showHUD:self.view message:@""];
}

-(void)webViewDidFinishLoad:(UIWebView *)webView{
    
    [LFHUD hideHud:self.view];
}


-(void)profieRequest{
    NSString *urlString =[NSString stringWithFormat:@"https://identity.%@/%@/api/v1.0/public/profile/",self.environment,self.network ];
    
    NSURL *url = [NSURL URLWithString:self.next];
    NSString *origin = [NSString stringWithFormat:@"http://%@",url.host];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:self.next forHTTPHeaderField:@"Referer"];
    [manager.requestSerializer setValue:origin forHTTPHeaderField:@"Origin"];
    [manager.responseSerializer.acceptableContentTypes setByAddingObject:@"*/*"];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSArray * cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSDictionary *cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    for (NSString *key in cookieHeaders) {
        [manager.requestSerializer setValue:cookieHeaders[key] forHTTPHeaderField:key];
    }
    NSString *baseString = [NSString stringWithFormat:@"https://identity.%@/%@/api/v1.0/public/profile/",self.environment,self.network];
    [manager GET:baseString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSError *error;
        if(responseObject!=nil){
            NSDictionary* jsonFromData = (NSDictionary*)[NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers error:&error];
            self.verifiedEmail = YES;
            if(!error && [[jsonFromData valueForKey:@"code"] integerValue] == 200){
                NSDictionary *data = [jsonFromData valueForKey:@"data"];
                if(data[@"email"] !=[NSNull null]){
                    [self dismissViewControllerAnimated:YES completion:^{
                        if([self.delegate respondsToSelector:@selector(didReceiveLFAuthToken:)]){
                            [self.delegate didReceiveLFAuthToken:[LFAuthViewController getLFSPCookie]];
                        }
                    }];
                }else{
                    NSString *urlString =[NSString stringWithFormat:@"https://identity.%@/%@/pages/profile/complete/?next=%@",self.environment,self.network,self.next ];
                    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString]]];
                }
            }
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
}
-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    if([[request.URL absoluteString] containsString:kCancelPath]){
        [self failAuth];
        return NO;
    }else if([LFAuthViewController isLoggedin] && !self.verifiedEmail){
        [self profieRequest];
        return YES;
    }
    NSString *profileCompleteUrl = [webView.request.URL absoluteString];
    if ([profileCompleteUrl containsString:@"lftoken"]) {
        [self dismissViewControllerAnimated:YES completion:^{
            if([self.delegate respondsToSelector:@selector(didReceiveLFAuthToken:)]){
                [self.delegate didReceiveLFAuthToken:[LFAuthViewController getLFSPCookie]];
            }
        }];
    }
    return YES;
}
-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    [LFHUD hideHud:self.view];
}

#pragma mark - public

- (instancetype)initWithEnvironment:(NSString*)environment network:(NSString*)network next:(NSString*)next
{
    self = [super init];
    if (self) {
        self.network =network;
        self.next = next;
        self.environment = environment;
    }
    return self;
}

+(id)getLFProfile{
    return [LFAuthViewController getLFSPCookie];
}

+(BOOL)isLoggedin{
    if([LFAuthViewController getLFSPCookie] != nil){
        return YES;
    }
    return NO;
}

+(void)logout{
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSHTTPCookie *cookie;
    for(cookie in [storage cookies]) {
        NSLog(@"cookie deleted is :%@", cookie);
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}



#pragma mark - private

-(void)getDataFromCookie{
    if([LFAuthViewController isLoggedin]){
        
    }
}

+(NSString*)getLFSPCookie{
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSHTTPCookie *cookie;
    for(cookie in [storage cookies])
    {
        if([cookie.name isEqualToString:kLFSPCookie] && cookie.value.length>0){
            return cookie.value;
        }
    }
    return nil;
}

-(void)failAuth{
    [self dismissViewControllerAnimated:YES completion:^{
        if([self.delegate respondsToSelector:@selector(didFailLFRequest)]){
            [self.delegate didFailLFRequest];
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - helper
- (NSString *)escapeValueForURLParameter:(NSString *)valueToEscape {
    return (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef) valueToEscape,
                                                                                  NULL, (CFStringRef) @"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
}
- (NSString* )valueForKey:(NSString* )key fromQueryItems:(NSArray *)queryItems{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems
                                  filteredArrayUsingPredicate:predicate]
                                 firstObject];
    return queryItem.value;
}

@end
