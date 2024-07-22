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

    /**
     * *********************************************************
     * @Method Name    : fetchPendingOrders
     * @description    : Helper method to fetch pending CourseOrders for a specific user.
     * @param          userId - ID of the user to fetch pending orders for.
     * @return         : List<Order__c> - List of pending orders for the given user.
     * *********************************************************
     */
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
    public static String addCoursesToOrders(List<Object> courseOfferingList) {
        
        try {
            Map<String, Object> courseOfferingMap = deserializeCourseOffering(courseOfferingList[0]);
            Decimal price = extractPriceFromCourseOffering(courseOfferingMap);
            if (price == null) {
                return 'Warning: Course offering price is missing';
            }

            List<Order__c> pendingOrders = getPendingOrders();
            if (pendingOrders.isEmpty()) {
                pendingOrders = createPendingOrderForCurrentUser();
            }
            
            if (isCourseOfferingInCart(courseOfferingMap, pendingOrders[0].Id)) {
                return 'Info: Course Offering already added to cart';
            }

            Order_Line_Item__c orderLineItem = createOrderLineItem(courseOfferingMap, pendingOrders[0].Id, price);
            insertOrderLineItem(orderLineItem);

            return 'Success: Course added to cart';

        } catch (Exception e) {
            throw new AuraHandledException('Error adding course offerings to order: ' + e.getMessage() + e.getCause()+ e.getLineNumber() + e.getTypeName());
        }
    }

    /**
     * *********************************************************
     * @Method Name    : isCourseOfferingInCart
     * @description    : Checks if a given course offering is already present in the cart for a specific order.
     * @param courseOfferingMap : Map<String, Object> - Map containing course offering details.
     * @param orderId           : Id - The Id of the order to check against.
     * @return          : Boolean - True if the course offering is already in the cart, otherwise false.
     * *********************************************************
     */
    private static Boolean isCourseOfferingInCart(Map<String, Object> courseOfferingMap, Id orderId) {
        Id courseId = (Id) courseOfferingMap.get('id');
        List<Order_Line_Item__c> existingItems = [
            SELECT Id FROM Order_Line_Item__c
            WHERE Order__c = :orderId AND Course_Offering__c = :courseId
        ];
        return !existingItems.isEmpty();
    }

    /**
     * *********************************************************
     * @Method Name    : deserializeCourseOffering
     * @description    : Helper method to deserialize a course offering from an Object to a Map.
     * @param          courseOffering - The course offering object to deserialize.
     * @return         : Map<String, Object> - Deserialized course offering map.
     * *********************************************************
     */
    private static Map<String, Object> deserializeCourseOffering(Object courseOffering) {
        String jsonString = JSON.serialize(courseOffering);
        return (Map<String, Object>) JSON.deserializeUntyped(jsonString);
    }

    /**
     * *********************************************************
     * @Method Name    : extractPriceFromCourseOffering
     * @description    : Helper method to extract the price from a course offering map.
     * @param          courseOfferingMap - The course offering map.
     * @return         : Decimal - Price of the course offering.
     * @throws         : AuraHandledException - If the price is missing from the course offering.
     * *********************************************************
     */
    private static Decimal extractPriceFromCourseOffering(Map<String, Object> courseOfferingMap) {
        if (courseOfferingMap.containsKey('price')) {
            return (Decimal) courseOfferingMap.get('price');
        }
        throw new AuraHandledException('Course offering price is missing');
    }

    /**
     * *********************************************************
     * @Method Name    : createPendingOrderForCurrentUser
     * @description    : Helper method to create a pending order for the current user.
     * @return         : List<Order__c> - List containing the newly created pending order.
     * @throws         : AuraHandledException - If an error occurs while creating the order.
     * *********************************************************
     */
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

    /**
     * *********************************************************
     * @Method Name    : fetchUserContact
     * @description    : Helper method to fetch the contact ID of a user.
     * @param          userId - The user ID to fetch the contact for.
     * @return         : Id - Contact ID of the user.
     * *********************************************************
     */
    private static Id fetchUserContact(Id userId) {
        return [
            SELECT ContactId 
            FROM User 
            WHERE Id = :userId 
            LIMIT 1
        ].ContactId;
    }

    /**
     * *********************************************************
     * @Method Name    : createOrderLineItem
     * @description    : Helper method to create an order line item.
     * @param          courseOfferingMap - The course offering map.
     * @param          orderId - The ID of the order to add the line item to.
     * @param          price - The price of the course offering.
     * @return         : Order_Line_Item__c - The created order line item.
     * *********************************************************
     */
    private static Order_Line_Item__c createOrderLineItem(Map<String, Object> courseOfferingMap, Id orderId, Decimal price) {
        return new Order_Line_Item__c(
            Course_Offering__c = (Id) courseOfferingMap.get('id'),
            Order__c = orderId,
            Price__c = price
        );
    }

    /**
     * *********************************************************
     * @Method Name    : insertOrderLineItem
     * @description    : Helper method to insert an order line item into the database.
     * @param          orderLineItem - The order line item to insert.
     * @throws         : AuraHandledException - If an error occurs while inserting the order line item.
     * *********************************************************
     */
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

    /**
     * *********************************************************
     * @Method Name    : fetchOrderLineItems
     * @description    : Helper method to fetch order line items for a specific order.
     * @param          orderId - The ID of the order to fetch line items for.
     * @return         : List<Order_Line_Item__c> - List of order line items for the given order.
     * *********************************************************
     */
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

    /**
     * *********************************************************
     * @Method Name    : deleteCourseOrderLineItem
     * @description    : Helper method to delete an order line item.
     * @param          courseLineItemId - The ID of the course line item to delete.
     * @throws         : AuraHandledException - If an error occurs while deleting the order line item.
     * *********************************************************
     */
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

    /**
     * *********************************************************
     * @Method Name    : fetchCourseOfferings
     * @description    : Helper method to fetch CourseOfferings based on provided IDs.
     * @param          courseIds - List of IDs of CourseOfferings to fetch.
     * @return         : List<CourseOffering> - List of fetched CourseOfferings.
     * *********************************************************
     */
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

    /**
     * *********************************************************
     * @Method Name    : fetchCourseDetails
     * @description    : Helper method to fetch details of a specific CourseOffering by ID.
     * @param          recordId - ID of the CourseOffering to fetch details for.
     * @return         : CourseOffering - Details of the CourseOffering.
     * @throws         : AuraHandledException - If no course offering is found for the given ID.
     * *********************************************************
     */
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
