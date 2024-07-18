/**
 * @description       : Test class for CourseOfferingController
 * @last modified on  : 07-11-2024
 * @last modified by  : anisha@concret.io
**/
@isTest
public class CourseOfferingControllerTest {
    
    @testSetup
    static void setup() {
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        Contact testContact = new Contact(
            LastName = 'Test Contact',
            Email = 'test@example.com'
        );
        insert testContact;

        Learning testLearning = new Learning(
            Name = 'Test Learning'
        );
        insert testLearning;

        LearningCourse testLearningCourse = new LearningCourse(
            Name = 'Test Learning Course',
            LearningId = testLearning.Id
        );
        insert testLearningCourse;

        CourseOffering testCourseOffering = new CourseOffering(
            Name = 'Test Course Offering',
            Price__c = 100.00,
            StartDate = Date.today(),
            LearningCourseId = testLearningCourse.Id
        );
        insert testCourseOffering;

        Order__c testOrder = new Order__c(
            Contact__c = testContact.Id,
            Status__c = 'Pending',
            OwnerId = testUser.Id
        );
        insert testOrder;

        Order_Line_Item__c testOrderLineItem = new Order_Line_Item__c(
            Course_Offering__c = testCourseOffering.Id,
            Order__c = testOrder.Id,
            Price__c = 100.00
        );
        insert testOrderLineItem;
    }
    
    @isTest
    static void testGetPendingOrders() {
        Test.startTest();
        List<Order__c> pendingOrders = CourseOfferingController.getPendingOrders();
        Test.stopTest();
        System.assertNotEquals(0, pendingOrders.size(), 'There should be pending orders');
    }

    @isTest
    static void testAddCoursesToOrders() {
        List<Object> courseOfferingList = new List<Object>();
        Map<String, Object> courseOfferingMap = new Map<String, Object>{
            'id' => [SELECT Id FROM CourseOffering LIMIT 1].Id,
            'price' => 100.00
        };
        courseOfferingList.add(courseOfferingMap);

        Test.startTest();
        CourseOfferingController.addCoursesToOrders(courseOfferingList);
        Test.stopTest();

        List<Order_Line_Item__c> orderLineItems = [SELECT Id FROM Order_Line_Item__c];
        System.assertNotEquals(0, orderLineItems.size(), 'Order line item should be added');
    }

    @isTest
    static void testAddCoursesToOrdersNoPendingOrder() {
        delete [SELECT Id FROM Order__c WHERE Status__c = 'Pending'];
        
        List<Object> courseOfferingList = new List<Object>();
        Map<String, Object> courseOfferingMap = new Map<String, Object>{
            'id' => [SELECT Id FROM CourseOffering LIMIT 1].Id,
            'price' => 100.00
        };
        courseOfferingList.add(courseOfferingMap);

        Test.startTest();
        CourseOfferingController.addCoursesToOrders(courseOfferingList);
        Test.stopTest();

        List<Order_Line_Item__c> orderLineItems = [SELECT Id FROM Order_Line_Item__c];
        System.assertNotEquals(0, orderLineItems.size(), 'Order line item should be added');
        List<Order__c> pendingOrders = [SELECT Id FROM Order__c WHERE Status__c = 'Pending'];
        System.assertNotEquals(0, pendingOrders.size(), 'New pending order should be created');
    }

    @isTest
    static void testGetOrderLineItems() {
        Order__c testOrder = [SELECT Id FROM Order__c LIMIT 1];

        Test.startTest();
        List<Order_Line_Item__c> orderLineItems = CourseOfferingController.getOrderLineItems(testOrder.Id);
        Test.stopTest();

        System.assertNotEquals(0, orderLineItems.size(), 'Order line items should be fetched');
    }

    @isTest
    static void testDeleteCourseOrderAndItems() {
        Order_Line_Item__c testOrderLineItem = [SELECT Id FROM Order_Line_Item__c LIMIT 1];

        Test.startTest();
        CourseOfferingController.deleteCourseOrderAndItems(testOrderLineItem.Id);
        Test.stopTest();

        List<Order_Line_Item__c> orderLineItems = [SELECT Id FROM Order_Line_Item__c WHERE Id = :testOrderLineItem.Id];
        System.assertEquals(0, orderLineItems.size(), 'Order line item should be deleted');
    }

    @isTest
static void testDeleteCourseOrderAndItemsWithError() {
    // Fetch a valid Order_Line_Item__c ID from the setup
    Order_Line_Item__c testOrderLineItem = [SELECT Id FROM Order_Line_Item__c LIMIT 1];

    try {
        Test.startTest();
        CourseOfferingController.deleteCourseOrderAndItems(testOrderLineItem.Id);
        Test.stopTest();

        List<Order_Line_Item__c> orderLineItems = [SELECT Id FROM Order_Line_Item__c WHERE Id = :testOrderLineItem.Id];
        System.assertEquals(0, orderLineItems.size(), 'Order line item should be deleted');
    } catch (AuraHandledException e) {
        System.assert(false, 'Exception should not have been thrown');
    }
}


    @isTest
    static void testValidateAndAdjustPrices() {
        CourseOffering testCourseOffering = [SELECT Id FROM CourseOffering LIMIT 1];

        List<Id> courseIds = new List<Id>{testCourseOffering.Id};

        Test.startTest();
        List<CourseOffering> adjustedCourses = CourseOfferingController.validateAndAdjustPrices(courseIds);
        Test.stopTest();

        System.assertNotEquals(0, adjustedCourses.size(), 'Adjusted courses should be fetched');
    }

    @isTest
    static void testGetCourseDetails() {
        CourseOffering testCourseOffering = [SELECT Id FROM CourseOffering LIMIT 1];

        Test.startTest();
        CourseOffering fetchedCourse = CourseOfferingController.getCourseDetails(testCourseOffering.Id);
        Test.stopTest();

        System.assertNotEquals(null, fetchedCourse, 'Course offering should be fetched');
    }

}