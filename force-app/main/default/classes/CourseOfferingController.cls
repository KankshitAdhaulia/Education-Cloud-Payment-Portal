/**
 * @description       : 
 * @author            : anisha@concret.io
 * @group             : 
 * @last modified on  : 07-04-2024
 * @last modified by  : anisha@concret.io
**/

/**
 * @description       : Apex controller for handling course order and order line items
 * @author            : anisha@concret.io
 * @group             :
 * @last modified on  : 07-04-2024
 * @last modified by  : anisha@concret.io
**/
public with sharing class CourseOfferingController {




    // Fetches pending CourseOrders for the current user
    @AuraEnabled
    public static List<Order__c> getPendingOrders() {
        Id currentUserId = UserInfo.getUserId();
        List<Order__c> pendingOrders = [
            SELECT Id, Status__c, OwnerId  
            FROM Order__c
            WHERE Status__c = 'Pending' AND OwnerId = :currentUserId
        ];
       
        System.debug('getPendingOrders - Found ' + pendingOrders.size() + ' pending orders for user ' + currentUserId);
        return pendingOrders;
    }




    @AuraEnabled
    public static void addCoursesToOrders(List<Object> courseOfferingList) {
    Id currentUserId = UserInfo.getUserId();

    // System.debug('courseOfferingList>>>'+courseOfferingList[0]);
    // System.debug('courseOfferingList>>>'+courseOfferingList[0].price);


    String jsonString = JSON.serialize(courseOfferingList[0]);
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

        // Assuming 'price' is a Decimal field in the JSON object
        if (jsonMap.containsKey('price')) {
            Decimal price = (Decimal) jsonMap.get('price');
            System.debug('Price of first course offering: ' + price);
        }

    // Fetch existing pending orders for the current user
    List<Order__c> pendingOrders = [
        SELECT Id
        FROM Order__c
        WHERE Status__c = 'Pending' AND OwnerId = :currentUserId
        LIMIT 1
    ];




    Order__c orderToUpdate;
    if (!pendingOrders.isEmpty()) {
        orderToUpdate = pendingOrders[0];
        System.debug('addCoursesToOrders - Using existing order with ID: ' + orderToUpdate.Id);
    } else {
        List<User> conId = [SELECT ContactId FROM User WHERE Id=:currentUserId LIMIT 1];
        orderToUpdate = new Order__c(Contact__c = conId[0].ContactId, Status__c = 'Pending');
        System.debug('addCoursesToOrders - Creating new order for ConId ' + conId[0].ContactId);
        System.debug('addCoursesToOrders - Creating new order for user ' + currentUserId);
        insert orderToUpdate;
        System.debug('addCoursesToOrders - Created new order with ID: ' + orderToUpdate.Id);
    }


    // // Fetch CourseOfferings with Price__c field
    // List<CourseOffering> courseOfferings = [
    //     SELECT Id, Price__c
    //     FROM CourseOffering
    //     WHERE Id IN :courseOfferingIds
    // ];


    // // Prepare order line items to add
    //     List<Order_Line_Item__c> itemsToAdd = new List<Order_Line_Item__c>();
    //     for (CourseOffering offering : courseOfferings) {
    //         itemsToAdd.add(new Order_Line_Item__c(
    //             Course_Offering__c = offering.Id,
    //             Order__c = orderToUpdate.Id,
    //             Price__c = offering.Price__c
    //         ));
    //     }

    // Prepare order line items to add
    List<Order_Line_Item__c> itemsToAdd = new List<Order_Line_Item__c>();

        itemsToAdd.add(new Order_Line_Item__c(
            Course_Offering__c = (Id)jsonMap.get('id'),
            Order__c = orderToUpdate.Id,
            Price__c = (Decimal)jsonMap.get('price')
        ));
       
    




    // // Bulk insert order line items
    try {
        if (!itemsToAdd.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(itemsToAdd, false);
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    for (Database.Error error : result.getErrors()) {
                        System.debug('Error adding order line item: ' + error.getMessage());
                    }
                    throw new AuraHandledException('Error adding course offerings to order ');
                }
            }
        }
        System.debug('addCoursesToOrders - items added: ' + itemsToAdd.size());
    } catch (Exception e) {
        System.debug('Error adding course offerings to order: ' + e.getMessage());
        throw new AuraHandledException('Error adding course offerings to order: ' + e.getMessage());
    }
}








    @AuraEnabled
    public static List<Order_Line_Item__c> getOrderLineItems(String orderId) {
        // Fetch order line items related to the specified order ID
        List<Order_Line_Item__c> orderLineItems = [
            SELECT Id, Course_Offering__c, Course_Offering__r.Name, Course_Offering__r.StartDate, Course_Offering__r.Price__c, Course_Offering__r.LearningCourse.Name
            FROM Order_Line_Item__c
            WHERE Order__c = :orderId
        ];




        System.debug('getOrderLineItems - Found ' + orderLineItems.size() + ' order line items for order ID ' + orderId);
        return orderLineItems;
    }




    @AuraEnabled
public static void deleteCourseOrderAndItems(List<Id> courseIds) {
    // Query and delete order line items related to the course IDs
    List<Order_Line_Item__c> itemsToDelete = [
        SELECT Id, Order__c, Course_Offering__c
        FROM Order_Line_Item__c
        WHERE Course_Offering__c IN :courseIds
        LIMIT 1
    ];




    // Separate the items to delete and items to keep in the cart
    List<Order_Line_Item__c> itemsToKeep = new List<Order_Line_Item__c>();
    Set<Id> orderIdsToUpdate = new Set<Id>();




    for (Order_Line_Item__c item : itemsToDelete) {
        if (!courseIds.contains(item.Course_Offering__c)) {
            itemsToKeep.add(item);
            orderIdsToUpdate.add(item.Order__c);
        }
    }




    // Update orders that still have items after deletion
    List<Order__c> ordersToUpdate = [
        SELECT Id
        FROM Order__c
        WHERE Id IN :orderIdsToUpdate
        AND Status__c = 'Pending'
    ];




    try {
        // Delete items marked for deletion
        delete itemsToDelete;
        System.debug('deleteCourseOrderAndItems - Deleted ' + itemsToDelete.size() + ' order line items for course IDs ' + courseIds);




        // Update orders if needed
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
            System.debug('deleteCourseOrderAndItems - Updated ' + ordersToUpdate.size() + ' orders after deletion');
        }
    } catch (Exception e) {
        System.debug('Error deleting course order and items: ' + e.getMessage());
       
    }
}








    // Validates and adjusts prices of CourseOfferings based on provided IDs
    @AuraEnabled
    public static List<CourseOffering> validateAndAdjustPrices(List<Id> courseIds) {
        List<CourseOffering> courseList = [
            SELECT Id, Name, StartDate, Price__c, LearningCourse.Name
            FROM CourseOffering
            WHERE Id IN :courseIds
        ];
       
        // Perform price adjustments as needed




        System.debug('validateAndAdjustPrices - Adjusted prices for ' + courseList.size() + ' course offerings.');
        return courseList;
    }




    // Fetches course details including course offerings
    @AuraEnabled
    public static List<LearningCourse> getCourseDetails(List<Id> recordIds) {
        List<LearningCourse> courses = [
            SELECT Id, Name,
                (SELECT Id, Name, StartDate, Price__c FROM CourseOfferings WHERE Id IN :recordIds)
            FROM LearningCourse
            WHERE Id IN (SELECT LearningCourseId FROM CourseOffering WHERE Id IN :recordIds)
        ];




        System.debug('getCourseDetails - courses: ' + courses);
        return courses;
    }
}