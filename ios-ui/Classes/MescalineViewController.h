//
//  MescalineViewController.h
//  Mescaline
//
//  Created by Stefan Kersten on 30.03.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <vector>
#include "GlobalTypes.h"

@interface MescalineViewController : UIViewController {	
	BOOL drag;
	std::vector<int> regionsArray;
}

-(RegionList)getRegionList;


@end

