/**
 *  This script is an example recommender (using made up data) showing how you can create recommendations
 *  from determining if an item is in stock or not.  This information must be determined by metadata
 *  that previously exists.
 */
import 'recommenders.pig';

%default INPUT_PATH_PURCHASES '../data/retail/purchases.json'
%default INPUT_PATH_WISHLIST '../data/retail/wishlists.json'
%default INPUT_PATH_INVENTORY '../data/retail/inventory.json'
%default OUTPUT_PATH '../data/retail/out/in_stock'


/******* Load Data **********/

--Get purchase signals
purchase_input = LOAD '$INPUT_PATH_PURCHASES' USING org.apache.pig.piggybank.storage.JsonLoader(
                    'row_id: int, 
                     movie_id: chararray, 
                     movie_name: chararray, 
                     user_id: chararray, 
                     purchase_price: int');

--Get wishlist signals
wishlist_input =  LOAD '$INPUT_PATH_WISHLIST' USING org.apache.pig.piggybank.storage.JsonLoader(
                     'row_id: int, 
                      movie_id: chararray, 
                      movie_name: chararray, 
                      user_id: chararray');



/******* Convert Data to Signals **********/

-- Start with choosing 1 as max weight for a signal.
purchase_signals = FOREACH purchase_input GENERATE
                        user_id    as user,
                        movie_name as item,
                        1.0        as weight; 


-- Start with choosing 0.5 as weight for wishlist items because that is a weaker signal than
-- purchasing an item.
wishlist_signals = FOREACH wishlist_input GENERATE
                        user_id    as user,
                        movie_name as item,
                        0.5        as weight; 

user_signals = UNION purchase_signals, wishlist_signals;

/******** Changes for Consideration of Items in Stock  ******/
inventory_input = LOAD '$INPUT_PATH_INVENTORY' USING org.apache.pig.piggybank.storage.JsonLoader(
                     'movie_title: chararray, 
                      stock: int,
                      genres: bag{tuple(content:chararray)}');
-- recsys__GetItemItemRecommendations_WithSourceItems utilizes source_items to have schema as such
-- where the item is the only field
source_items = FOREACH (FILTER inventory_input BY stock > 0) GENERATE
                      movie_title as item;


/******* Use Mortar recommendation engine to convert signals to recommendations **********/
-- Use of non standard Mortar Recommendation engine macro
item_item_recs = recsys__GetItemItemRecommendations_WithSourceItems(user_signals, source_items);
user_item_recs = recsys__GetUserItemRecommendations(user_signals, item_item_recs);


/******* Store recommendations **********/

--  If your output folder exists already, hadoop will refuse to write data to it.
rmf $OUTPUT_PATH/item_item_recs;
rmf $OUTPUT_PATH/user_item_recs;

store item_item_recs into '$OUTPUT_PATH/item_item_recs' using PigStorage();
store user_item_recs into '$OUTPUT_PATH/user_item_recs' using PigStorage();
