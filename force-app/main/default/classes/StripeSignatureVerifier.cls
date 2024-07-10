/**
 * *********************************************************
 * Apex Class Name    : StripeSignatureVerifier
 * Created Date       : June 25, 2024
 * @description       : This class is responsible for verifying the 
 *                      signature of incoming Stripe webhook events to 
 *                      ensure that they are legitimate and have not 
 *                      been tampered with.
 * @developer         : Kankshit Adhaulia
 * @deprecated        : This class is deprecated as of July 4, 2024. No need to handle Webhook.
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   25-06-2024   Kankshit Adhaulia    Initial Version
 * 2.0   04-07-2025   Kankshit Adhaulia    Deprecating this class(No need to handle Webhook)
 * *********************************************************
 */

public class StripeSignatureVerifier {
    /**
     * *********************************************************
     * @Method Name    : verifySignature
     * @description    : This method verifies the Stripe webhook signature.
     * @param stripeSignatureHeader : String - The Stripe-Signature header from the request.
     * @param jsonString            : String - The JSON payload of the webhook event.
     * @return                      : Boolean - True if the signature is valid, false otherwise.
     * *********************************************************
     */
    public static Boolean verifySignature(String stripeSignatureHeader, String jsonString) {
        String webhookSecret = Stripe_Webhook_Secret__mdt.getInstance('Signing_Secret').Webhook_Key__c;

        Map<String, String> signatureMap = new Map<String, String>();
        for (String part : stripeSignatureHeader.split(',')) {
            List<String> keyValue = part.split('=');
            if (keyValue.size() == 2) {
                signatureMap.put(keyValue[0].trim(), keyValue[1].trim());
            }
        }
        String timestamp = signatureMap.get('t');
        String v1Signature = signatureMap.get('v1');

        if (String.isBlank(timestamp) || String.isBlank(v1Signature)) {
            return false;
        }

        String signedPayload = timestamp + '.' + jsonString;
        Blob key = Blob.valueOf(webhookSecret);
        Blob data = Blob.valueOf(signedPayload);
        Blob computedSignature = Crypto.generateMac('HMACSHA256', data, key);
        String expectedSignature = EncodingUtil.convertToHex(computedSignature);

        return constantTimeCompare(expectedSignature, v1Signature);
    }

    /**
     * *********************************************************
     * @Method Name    : constantTimeCompare
     * @description    : This method performs a constant-time comparison of two strings
     *                   to avoid timing attacks.
     * @param expectedSignature : String - The expected signature.
     * @param actualSignature   : String - The actual signature to compare.
     * @return                  : Boolean - True if the strings are equal, false otherwise.
     * *********************************************************
     */
    private static Boolean constantTimeCompare(String expectedSignature, String actualSignature) {
        if (expectedSignature.length() != actualSignature.length()) {
            return false;
        }
        Integer result = 0;
        for (Integer index = 0; index < expectedSignature.length(); index++) {
            result |= expectedSignature.charAt(index) ^ actualSignature.charAt(index);
        }
        return result == 0;
    }
}
