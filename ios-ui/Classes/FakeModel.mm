//
//  fake_model.m
//  Mescaline
//
//  Created by maule on 26.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FakeModel.h"
#include "GlobalTypes.h"

static FakeModel* sharedManager = nil;

@implementation FakeModel


+ (FakeModel*)sharedManager {
    @synchronized(self) {
        if (sharedManager == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedManager == nil) {
            sharedManager = [super allocWithZone:zone];
            return sharedManager;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}


-(id)init {
    self = [super init];
    return self;
}


- (int)numRegions{
    return 6;
}

- (NSString *)dataFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
                                                         NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:kFilename];
}


//int numRegions = 6;


-(RegionList)getRegionList
{	
	int nr = [self numRegions];
	RegionList rs;
	for (int i=0; i < nr; i++) {
		float x = rand()/(float)RAND_MAX;
		float y = rand()/(float)RAND_MAX;
		float rad = rand()/(float)RAND_MAX;
		rs.push_back(Mescaline::Region(x,y,(rad*100)+20));
		
	}
	return rs;
}



- (PointList)getPointList:(int)numPoints
{	
	
	PointList ps;
	for (int i=0; i < numPoints; i++) {
		
		float x = rand()/(float)RAND_MAX;
		float y = rand()/(float)RAND_MAX;
		
		ps.push_back(Mescaline::Point(x, y));
	}
	return ps;
}


- (void)getData {
    
    if (sqlite3_open([[self dataFilePath] UTF8String], &database)
        != SQLITE_OK) {
        sqlite3_close(database);
        NSAssert(0, @"Failed to open database");
    }
    NSString *query = @"SELECT sf.id, sf.url, u.id as uid, f.value FROM (SourceFile sf  join Unit u on u.sourceFile=sf.id)  join Feature f on u.id = f.unit where f.descriptor =3";
    sqlite3_stmt *statement;
//    PointList ps;

    if (sqlite3_prepare_v2( database, [query UTF8String],
                           -1, &statement, nil) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {

            //sqlite3_int64 row = sqlite3_column_int64(statement, 0);
            //int *rowData = sqlite3_column_text(statement, 2);
            //char *rowData = (char *)sqlite3_column_text(statement, 1);
            //NSString *aUrl = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 1)];
            //NSLog(@"s id = %i", row);
            //float x = rand()/(float)RAND_MAX;
            //float y = rand()/(float)RAND_MAX;
            
  //          ps.push_back(Mescaline::Point(x, y));

           
        }
        sqlite3_finalize(statement);
    } 
	//return ps;
}


- (CGPoint)setPosition:(CGPoint)currentPosition
{
//	NSLog(@"%f", currentPosition.x);
//	NSLog(@"%f", currentPosition.y);
	return currentPosition;
}

@end
