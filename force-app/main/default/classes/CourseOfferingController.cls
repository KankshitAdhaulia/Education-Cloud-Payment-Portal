/**
 * *********************************************************
 * @description       : Apex controller for handling course order and order line items
 * @group             : 
 * @last modified on  : 07-09-2024
 * @last modified by  : anisha@concret.io
 * *********************************************************
 */
public with sharing class CourseOfferingController {
    
    /**
     * *********************************************************
     * @Method Name    : getPendingOrders
     * @description    : Fetches pending CourseOrders for the current user.
     * @return         : List<Order__c> - List of pending orders.
     * *********************************************************
     */
    @AuraEnabled
    public static List<Order__c> getPendingOrders() {
        Id currentUserId = UserInfo.getUserId();
        return fetchPendingOrders(currentUserId);
    }

    private static List<Order__c> fetchPendingOrders(Id userId) {
        return [
            SELECT Id, Status__c, OwnerId
            FROM Order__c
            WHERE Status__c = 'Pending' AND OwnerId = :userId
        ];
    }

    /**
     * *********************************************************
     * @Method Name    : addCoursesToOrders
     * @description    : Adds courses to pending orders for the current user.
     * @param courseOfferingList : List<Object> - List of course offerings to add.
     * @throws         : AuraHandledException - If an error occurs while adding courses to orders.
     * *********************************************************
     */
    @AuraEnabled
    public static void addCoursesToOrders(List<Object> courseOfferingList) {
        try {
            Map<String, Object> courseOfferingMap = deserializeCourseOffering(courseOfferingList[0]);
            Decimal price = extractPriceFromCourseOffering(courseOfferingMap);

            List<Order__c> pendingOrders = getPendingOrders();
            if (pendingOrders.isEmpty()) {
                pendingOrders = createPendingOrderForCurrentUser();
            }

            Order_Line_Item__c orderLineItem = createOrderLineItem(courseOfferingMap, pendingOrders[0].Id, price);
            insertOrderLineItem(orderLineItem);

        } catch (Exception e) {
            throw new AuraHandledException('Error adding course offerings to order: ' + e.getMessage() + e.getCause()+ e.getLineNumber() + e.getTypeName());
        }
    }

    private static Map<String, Object> deserializeCourseOffering(Object courseOffering) {
        String jsonString = JSON.serialize(courseOffering);
        return (Map<String, Object>) JSON.deserializeUntyped(jsonString);
    }

    private static Decimal extractPriceFromCourseOffering(Map<String, Object> courseOfferingMap) {
        if (courseOfferingMap.containsKey('price')) {
            return (Decimal) courseOfferingMap.get('price');
        }
        throw new AuraHandledException('Course offering price is missing');
    }

    private static List<Order__c> createPendingOrderForCurrentUser() {
        Id currentUserId = UserInfo.getUserId();
        Id contact = fetchUserContact(currentUserId);
        
        List<Order__c> newOrder = new List<Order__c>();
        newOrder.add(new Order__c(Contact__c = contact, Status__c = 'Pending'));
        
        try {
            insert newOrder;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating order: ' + e.getMessage());
        }

        return newOrder;
    }

    private static Id fetchUserContact(Id userId) {
        return [
            SELECT ContactId 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ].ContactId;
        // if (!userList.isEmpty()) {
        //     return [SELECT Id FROM Contact WHERE Id = :userList[0].ContactId LIMIT 1];
        // }
        //throw new AuraHandledException('User contact not found');
    }

    private static Order_Line_Item__c createOrderLineItem(Map<String, Object> courseOfferingMap, Id orderId, Decimal price) {
        return new Order_Line_Item__c(
            Course_Offering__c = (Id) courseOfferingMap.get('id'),
            Order__c = orderId,
            Price__c = price
        );
    }

    private static void insertOrderLineItem(Order_Line_Item__c orderLineItem) {
        Database.SaveResult result = Database.insert(orderLineItem, false);
        if (!result.isSuccess()) {
            Database.Error error = result.getErrors()[0];
            throw new AuraHandledException('Error adding order line item: ' + error.getMessage());
        }
    }

    /**
     * *********************************************************
     * @Method Name    : getOrderLineItems
     * @description    : Fetches order line items related to a specific order ID.
     * @param orderId  : String - ID of the order to fetch line items for.
     * @return         : List<Order_Line_Item__c> - List of order line items.
     * *********************************************************
     */
    @AuraEnabled
    public static List<Order_Line_Item__c> getOrderLineItems(String orderId) {
        return fetchOrderLineItems(orderId);
    }

    private static List<Order_Line_Item__c> fetchOrderLineItems(String orderId) {
        return [
            SELECT Id, Course_Offering__c, Course_Offering__r.Name, Course_Offering__r.StartDate, 
                   Course_Offering__r.Price__c, Course_Offering__r.LearningCourse.Name
            FROM Order_Line_Item__c
            WHERE Order__c = :orderId
        ];
    }

    /**
     * *********************************************************
     * @Method Name    : deleteCourseOrderAndItems
     * @description    : Deletes course order and related items.
     * @param courseIds : String - Comma-separated IDs of order line items to delete.
     * @throws         : AuraHandledException - If an error occurs while deleting course order items.
     * *********************************************************
     */
    @AuraEnabled
    public static void deleteCourseOrderAndItems(String courseIds) {
        Id courseLineItemId = (Id) courseIds;
        deleteCourseOrderLineItem(courseLineItemId);
    }

    private static void deleteCourseOrderLineItem(Id courseLineItemId) {
        try {
            if (courseLineItemId != null) {
                Database.DeleteResult result = Database.delete(courseLineItemId, false);
                if (!result.isSuccess()) {
                    Database.Error error = result.getErrors()[0];
                    throw new AuraHandledException('Error deleting order line: ' + error.getMessage());
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting course offerings to order: ' + e.getMessage());
        }
    }

    /**
     * *********************************************************
     * @Method Name    : validateAndAdjustPrices
     * @description    : Validates and adjusts prices of CourseOfferings based on provided IDs.
     * @param courseIds : List<Id> - List of IDs of CourseOfferings to validate and adjust.
     * @return         : List<CourseOffering> - List of validated CourseOfferings with adjusted prices.
     * *********************************************************
     */
    @AuraEnabled
    public static List<CourseOffering> validateAndAdjustPrices(List<Id> courseIds) {
        return fetchCourseOfferings(courseIds);
    }

    private static List<CourseOffering> fetchCourseOfferings(List<Id> courseIds) {
        return [
            SELECT Id, Name, StartDate, Price__c, LearningCourse.Name
            FROM CourseOffering
            WHERE Id IN :courseIds
        ];
    }

    /**
     * *********************************************************
     * @Method Name    : getCourseDetails
     * @description    : Fetches details of a specific CourseOffering by ID.
     * @param recordId : Id - ID of the CourseOffering to fetch details for.
     * @return         : CourseOffering - Details of the CourseOffering.
     * @throws         : AuraHandledException - If no course offering is found for the given ID or an error occurs.
     * *********************************************************
     */
    @AuraEnabled
    public static CourseOffering getCourseDetails(Id recordId) {
        try {
            return fetchCourseDetails(recordId);
        } catch (Exception e) {
            throw new AuraHandledException('Error loading course: ' + e.getMessage());
        }
    }

    private static CourseOffering fetchCourseDetails(Id recordId) {
        CourseOffering courseOffering = [
            SELECT Id, Name, StartDate, Price__c, LearningCourse.Name
            FROM CourseOffering
            WHERE Id = :recordId
        ];
        if (courseOffering == null) {
            throw new AuraHandledException('No course offering found for the given ID');
        }
        return courseOffering;
    }
}