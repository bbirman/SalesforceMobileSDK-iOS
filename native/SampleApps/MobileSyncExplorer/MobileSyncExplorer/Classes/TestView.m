//
//  TestView.m
//  MobileSyncExplorer
//
//  Created by Brianna Birman on 9/17/25.
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "TestView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TestView ()

@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) UILabel *headerView;

@end

@implementation TestView

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.items = @[@"Item 1", @"Item 2", @"Item 3", @"Item 4", @"Item 5"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Test View";
    
    // Create and configure the header view
    self.headerView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 60)];
    self.headerView.text = @"Hello from Test View!";
    self.headerView.textAlignment = NSTextAlignmentCenter;
    self.headerView.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    self.headerView.textColor = [UIColor labelColor];
    self.headerView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // Set the header view
    self.tableView.tableHeaderView = self.headerView;
    
    // Register cell class
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = self.items[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *selectedItem = self.items[indexPath.row];
    self.headerView.text = [NSString stringWithFormat:@"Selected: %@", selectedItem];
}

@end

NS_ASSUME_NONNULL_END
