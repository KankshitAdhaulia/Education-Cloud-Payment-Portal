/**
 * @description       : 
 * @author            : anisha@concret.io
 * @group             : 
 * @last modified on  : 07-16-2024
 * @last modified by  : anisha@concret.io
**/
@IsTest
public class StripeControllerTest {

        private static User communityUser = [SELECT Id, Contact.Id FROM User WHERE Profile.Name = 'Customer Community Plus User' LIMIT 1];
        private static Id contactId;
        private static String SESSION_ID = 'cs_test_b1dt3WhiiGpjEMNQKyBjUaswk3Y2WbItUp4QlzEGOsN8IULHWtMHKpG0Ip';
        private static String PAYMENT_INTENT = 'pi_3PNTrpSB8JX5Bkem1J1LHIGL';
        private static String HOSTED_INVOICE_URL = 'https://invoice.stripe.com/i/acct_1PNUWUP7Jgv3BSNP/test_YWNjdF8xUE5VV1VQN';
        
        
        @IsTest
        static void testCreateCheckoutSession() {
 
            // Mock HTTP response
            Test.setMock(HttpCalloutMock.class, new StripeServiceMock());

            // Call the method
            String courseOrderLines = '[{"id":"a0IF900000kYJFDMA4","courseid":"0P0F9000000XZxzKAG","name":"Computational Thinking","learningCourse":"Computer Science I","startingDate":"2025-06-25T19:00:00.000Z","price":"1500"},{"id":"a0IF900000kYJFEMA4","courseid":"0P0F9000000XZthKAG","name":"Computer Science II - Fall 25","learningCourse":"Expand","startingDate":"2022-06-29T06:30:00.000Z","price":"600"},{"id":"a0IF900000kYJJ5MAO","courseid":"0P0F9000000XZy9KAG","name":"Deep Learning Specialization","learningCourse":"Artificial Intelligence","startingDate":"2024-06-13T08:00:00.000Z","price":"97800"}]';
            
            Test.startTest();
            String checkoutSessionUrl = StripeController.createCheckoutSession(courseOrderLines);
            Test.stopTest();

            // Verify the results
            System.assertNotEquals(null, checkoutSessionUrl, 'The checkout session URL should not be null');
            System.assert(checkoutSessionUrl.startsWith('https://checkout.stripe.com/'), 'The URL should start with the Stripe checkout prefix');
        }


        @IsTest
        static void testFetchInvoiceURL() {
            Order__c testOrder = new Order__c(
                Name = 'Test Order',
                Payment_Intent__c = PAYMENT_INTENT,
                Hosted_Invoice_URL__c = HOSTED_INVOICE_URL
            );
            insert testOrder;

            Test.startTest();
            String invoiceUrl = StripeController.fetchInvoiceURL(PAYMENT_INTENT);
            Test.stopTest();

            System.assertNotEquals(null, invoiceUrl, 'The invoice URL should not be null');
            System.assertEquals(HOSTED_INVOICE_URL, invoiceUrl, 'The fetched invoice URL should match the expected URL');
        }

        @IsTest
        static void testCreateCourseOfferingParticipant() {

            Contact testContact = new Contact(LastName = 'Test');
            insert testContact;

            Learning testLearning = new Learning(Name = 'Test Learning');
            insert testLearning;

            LearningCourse testLearningCourse = new LearningCourse(Name = 'Test Learning Course', LearningId = testLearning.Id);
            insert testLearningCourse;
            
            CourseOffering testCourseOffering = new CourseOffering(Name = 'Test Course Offering', LearningCourseId = testLearningCourse.Id, Price__c = 1000);
            insert testCourseOffering;

            Order__c testOrder = new Order__c(Name = 'Test Order', Contact__c = testContact.Id, Payment_Intent__c = 'test_payment_intent');
            insert testOrder;

            Order_Line_Item__c testOrderLineItem = new Order_Line_Item__c(Order__c = testOrder.Id, Course_Offering__c = testCourseOffering.Id);
            insert testOrderLineItem;

            
            Test.startTest();

            
            StripeController.createCourseOfferingParticipant(testOrder.Payment_Intent__c);

        
            List<CourseOfferingParticipant> participants = [SELECT Id FROM CourseOfferingParticipant];

        
            System.assertNotEquals(0, participants.size(), 'CourseOfferingParticipant records should have been inserted');

            Test.stopTest();
        }

        @IsTest
        static void testGetSessionDetails() {

            Learning testLearning = new Learning(Name = 'testLearning');
            insert testLearning;

            LearningCourse testLearningCourse = new LearningCourse(Name = 'testLearningCourse', LearningId = testLearning.Id);
            insert testLearningCourse;

            CourseOffering testCourseOffering = new CourseOffering(Name = 'Test Course Offering', StartDate = Date.today(), EndDate = Date.today().addDays(10), LearningCourseId = testLearningCourse.Id, Price__c = 1000);
            insert testCourseOffering;

            Order__c testOrder = new Order__c(
                Name = 'MyOrder1',
                Contact__c = communityUser.ContactId,
                Session_Id__c = SESSION_ID,
                Status__c = 'Pending'
            );
            insert testOrder;

            Test.setMock(HttpCalloutMock.class, new SessionMockHttpResponse());

            Test.startTest();
            Map<String,Object> sessionDetails = StripeController.getSessionDetails(SESSION_ID);
            Test.stopTest();

            System.assertEquals(PAYMENT_INTENT, sessionDetails.get('payment_intent'), 'Payment intent should match');
            // will add more asserts later whenever required
        }


        private class StripeServiceMock implements HttpCalloutMock {
            public HTTPResponse respond(HTTPRequest req) {
                HttpResponse res = new HttpResponse();
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"id": "cs_test_b1YV76omKTVcfIMT7FkYS22Y0Z5RbnyPsZkfy2oeacdlCAkBf1H1naIx0g", ' +
                    '"object": "checkout.session", ' +
                    '"after_expiration": null, ' +
                    '"allow_promotion_codes": true, ' +
                    '"amount_subtotal": 100, ' +
                    '"amount_total": 100, ' +
                    '"automatic_tax": {"enabled": false, "liability": null, "status": null}, ' +
                    '"billing_address_collection": null, ' +
                    '"cancel_url": "https://concretio3.my.site.com/eduConnectPortal/s/payment-cancel", ' +
                    '"client_reference_id": "'+ communityUser.Id +'", ' +
                    '"client_secret": null, ' +
                    '"consent": null, ' +
                    '"consent_collection": null, ' +
                    '"created": 1720767556, ' +
                    '"currency": "sgd", ' +
                    '"currency_conversion": null, ' +
                    '"custom_fields": [], ' +
                    '"custom_text": {"after_submit": null, "shipping_address": null, "submit": null, "terms_of_service_acceptance": null}, ' +
                    '"customer": null, ' +
                    '"customer_creation": "if_required", ' +
                    '"customer_details": null, ' +
                    '"customer_email": null, ' +
                    '"expires_at": 1720853955, ' +
                    '"invoice": null, ' +
                    '"invoice_creation": {"enabled": true, "invoice_data": {"account_tax_ids": null, "custom_fields": null, "description": null, "footer": null, "issuer": {"type": "self"}, "metadata": {}, "rendering_options": null}}, ' +
                    '"livemode": false, ' +
                    '"locale": null, ' +
                    '"metadata": {}, ' +
                    '"mode": "payment", ' +
                    '"payment_intent": null, ' +
                    '"payment_link": null, ' +
                    '"payment_method_collection": "if_required", ' +
                    '"payment_method_configuration_details": {"id": "pmc_1PNUXeP7Jgv3BSNPZSGQoZmG", "parent": null}, ' +
                    '"payment_method_options": {"card": {"request_three_d_secure": "automatic"}}, ' +
                    '"payment_method_types": ["card", "grabpay", "paynow", "link"], ' +
                    '"payment_status": "unpaid", ' +
                    '"phone_number_collection": {"enabled": false}, ' +
                    '"recovered_from": null, ' +
                    '"saved_payment_method_options": {"allow_redisplay_filters": ["always"], "payment_method_remove": null, "payment_method_save": null}, ' +
                    '"setup_intent": null, ' +
                    '"shipping_address_collection": null, ' +
                    '"shipping_cost": null, ' +
                    '"shipping_details": null, ' +
                    '"shipping_options": [], ' +
                    '"status": "open", ' +
                    '"submit_type": null, ' +
                    '"subscription": null, ' +
                    '"success_url": "https://concretio3.my.site.com/eduConnectPortal/success?session_id={CHECKOUT_SESSION_ID}", ' +
                    '"total_details": {"amount_discount": 0, "amount_shipping": 0, "amount_tax": 0}, ' +
                    '"ui_mode": "hosted", ' +
                    '"url": "https://checkout.stripe.com/c/pay/cs_test_b1YV76omKTVcfIMT7FkYS22Y0Z5RbnyPsZkfy2oeacdlCAkBf1H1naIx0g#fidkdWxOYHwnPyd1blpxYHZxWjA0VUtQUlBVMk9iczZHVktVSG4xXGQ0fTV2ZE50dUw9YERUbmZVbVJfS1dgM3E0RHxzU0hMPW9Bb19yN2czM0pwVVAxcmlNR2Z8PWBPfVdpQjV8dFRrSG9cNTVtQlZ%2Fb0lRdycpJ2N3amhWYHdzYHcnP3F3cGApJ2lkfGpwcVF8dWAnPydocGlxbFpscWBoJyknYGtkZ2lgVWlkZmBtamlhYHd2Jz9xd3BgeCUl"}'
                );
                res.setStatusCode(200);
                return res;
            }
        }

        private class SessionMockHttpResponse implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                // Create a new HTTP response
                HttpResponse res = new HttpResponse();
                res.setHeader('Content-Type', 'application/json');
                res.setStatusCode(200);
                res.setBody('{' +
                    '"id": "'+SESSION_ID+'",' +
                    '"object": "checkout.session",' +
                    '"after_expiration": null,' +
                    '"allow_promotion_codes": true,' +
                    '"amount_subtotal": 100,' +
                    '"amount_total": 100,' +
                    '"automatic_tax": {' +
                        '"enabled": false,' +
                        '"liability": null,' +
                        '"status": null' +
                    '},' +
                    '"billing_address_collection": null,' +
                    '"cancel_url": "https://example.com/cancel",' +
                    '"client_reference_id": "'+ communityUser.Id +'",' +
                    '"client_secret": null,' +
                    '"consent": null,' +
                    '"consent_collection": null,' +
                    '"created": 1717394105,' +
                    '"currency": "usd",' +
                    '"currency_conversion": null,' +
                    '"custom_fields": [],' +
                    '"custom_text": {' +
                        '"after_submit": null,' +
                        '"shipping_address": null,' +
                        '"submit": null,' +
                        '"terms_of_service_acceptance": null' +
                    '},' +
                    '"customer": {' +
                        '"id": "cus_QDvjLQDnLMiyqn",' +
                        '"object": "customer",' +
                        '"address": {' +
                            '"city": "Mathura",' +
                            '"country": "IN",' +
                            '"line1": "1233",' +
                            '"line2": "123",' +
                            '"postal_code": null,' +
                            '"state": null' +
                        '},' +
                        '"balance": 0,' +
                        '"created": 1717394137,' +
                        '"currency": null,' +
                        '"default_source": null,' +
                        '"delinquent": false,' +
                        '"description": null,' +
                        '"discount": null,' +
                        '"email": "kankshitadhaulia@gmail.com",' +
                        '"invoice_prefix": "67E7E2EE",' +
                        '"invoice_settings": {' +
                            '"custom_fields": null,' +
                            '"default_payment_method": null,' +
                            '"footer": null,' +
                            '"rendering_options": null' +
                        '},' +
                        '"livemode": false,' +
                        '"metadata": {},' +
                        '"name": "Test Name For Order",' +
                        '"next_invoice_sequence": 1,' +
                        '"phone": null,' +
                        '"preferred_locales": ["en-US"],' +
                        '"shipping": null,' +
                        '"tax_exempt": "none",' +
                        '"test_clock": null' +
                    '},' +
                    '"customer_creation": "if_required",' +
                    '"customer_details": {' +
                        '"address": null,' +
                        '"email": "kankshitadhaulia@gmail.com",' +
                        '"name": null,' +
                        '"phone": null,' +
                        '"tax_exempt": "none",' +
                        '"tax_ids": null' +
                    '},' +
                    '"customer_email": null,' +
                    '"expires_at": 1717480505,' +
                    '"invoice":{' +
                        '"number": "12345678",' +
                        '"hosted_invoice_url": "'+HOSTED_INVOICE_URL+'", ' +
                        '"amount_paid": 1234,' +
                        '"status": "paid",' +
                        '"currency": "sgd"' +
                    '},' +
                    '"invoice_creation": {' +
                        '"enabled": true,' +
                        '"invoice_data": {' +
                            '"account_tax_ids": null,' +
                            '"custom_fields": null,' +
                            '"description": null,' +
                            '"footer": null,' +
                            '"issuer": {' +
                                '"type": "self"' +
                            '},' +
                            '"metadata": {},' +
                            '"rendering_options": null' +
                        '}' +
                    '},' +
                    '"livemode": false,' +
                    '"locale": null,' +
                    '"metadata": {},' +
                    '"mode": "payment",' +
                    '"payment_intent": "'+PAYMENT_INTENT+'",' +
                    '"payment_link": null,' +
                    '"payment_method_collection": "if_required",' +
                    '"payment_method_configuration_details": {' +
                        '"id": "pmc_1PLgzWSB8JX5Bkem84Dnlj2r",' +
                        '"parent": null' +
                    '},' +
                    '"payment_method_options": {' +
                        '"card": {' +
                            '"request_three_d_secure": "automatic"' +
                        '}' +
                    '},' +
                    '"payment_method_types": ["card"],' +
                    '"payment_status": "unpaid",' +
                    '"phone_number_collection": {' +
                        '"enabled": false' +
                    '},' +
                    '"recovered_from": null,' +
                    '"saved_payment_method_options": {' +
                        '"allow_redisplay_filters": ["always"],' +
                        '"payment_method_remove": null,' +
                        '"payment_method_save": null' +
                    '},' +
                    '"setup_intent": null,' +
                    '"shipping_address_collection": null,' +
                    '"shipping_cost": null,' +
                    '"shipping_details": null,' +
                    '"shipping_options": [],' +
                    '"status": "paid",' +
                    '"submit_type": null,' +
                    '"subscription": null,' +
                    '"success_url": "https://example.com/success",' +
                    '"total_details": {' +
                        '"amount_discount": 0,' +
                        '"amount_shipping": 0,' +
                        '"amount_tax": 0' +
                    '},' +
                    '"ui_mode": "hosted",' +
                    '"url": null' +
                '}');
                return res;
            }
        }

        
        
}