/**
 * *********************************************************
 * Apex Class Name    : StripeWebhookController
 * Created Date       : June 25, 2024
 * @description       : This class handles incoming Stripe webhook events.
 *                      It processes the webhook payload and delegates 
 *                      tasks to the appropriate handlers based on the 
 *                      event type.
 * @developer         : Kankshit Adhaulia
 * @deprecated        : This class is deprecated as of July 4, 2024. No need to handle Webhook.
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   13-06-2024   Kankshit Adhaulia    Initial Version
 * 2.0   04-07-2025   Kankshit Adhaulia    Deprecating this class(No need to handle Webhook)
 * *********************************************************
 */

@RestResource(urlMapping='/StripeWebhook')
global class StripeWebhookController {

    

    /**
     * *********************************************************
     * @Method Name    : handleWebhook
     * @description    : This method handles the incoming Stripe webhook POST request,
     *                   parses the JSON payload, and processes it based on the event type.
     * @return         : String - A JSON response indicating the status of the processing.
     * *********************************************************
     */
     @HttpPost
    global static String handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String jsonString = req.requestBody.toString();
        System.debug('Received Stripe Webhook: ' + jsonString);

        /*String stripeSignatureHeader = req.headers.get('Stripe-Signature');
        if (String.isBlank(stripeSignatureHeader)) {
            return respondWithError(res, 'Missing Stripe-Signature header');
        }

        if (!StripeSignatureVerifier.verifySignature(stripeSignatureHeader, jsonString)) {
            return respondWithError(res, 'Invalid signature');
        }*/

        Map<String, Object> jsonMap;
        try {
            jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        } catch (Exception e) {
            return respondWithError(res, 'Invalid JSON payload');
        }
        String eventType = (String) jsonMap.get('type');
        if (eventType == null) {
            return respondWithError(res, 'Missing event type');
        }
        Map<String, Object> session = (Map<String, Object>) ((Map<String, Object>) jsonMap.get('data')).get('object');
        try{    
            if (eventType == 'checkout.session.completed') {
                Id orderId = StripeEventHandler.handleCheckoutSessionCompleted(session, eventType);
                return respondWithSuccess(res, orderId);
            } else if (eventType == 'invoice.paid') {
                Id orderId = StripeEventHandler.handleInvoicePaid(session, eventType);
                StripeEventHandler.createCourseOfferingParticipant(orderId);
                return respondWithSuccess(res, orderId);
            } else {
                return respondWithError(res, 'Invalid event type');
            }
        }catch (Exception e) {
            return respondWithError(res, 'Error processing event: ' + e.getMessage());
        }        
    }
    /**
     * *********************************************************
     * @Method Name    : respondWithError
     * @description    : This method returns an error response.
     * @param res      : RestResponse - The response object.
     * @param message  : String - The error message.
     * @return         : String - A JSON response indicating the error.
     * *********************************************************
     */
    private static String respondWithError(RestResponse res, String message) {
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 400;
        return '{"status": "error", "message": "' + message + '"}';
    }

    /**
     * *********************************************************
     * @Method Name    : respondWithSuccess
     * @description    : This method returns a success response.
     * @param res      : RestResponse - The response object.
     * @param orderId  : Id - The order ID.
     * @return         : String - A JSON response indicating the success.
     * *********************************************************
     */
    private static String respondWithSuccess(RestResponse res, Id orderId) {
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200;
        return '{"status": "success", "orderId": "' + orderId + '"}';
    }
}