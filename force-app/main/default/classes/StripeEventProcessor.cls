/**
 * *********************************************************
 * Apex Class Name    : StripeEventProcessor
 * Created Date       : July 03, 2024
 * @description       : This class implements the Queueable interface 
 *                      for processing Stripe events asynchronously.
 * @developer         : Kankshit Adhaulia
  * @deprecated        : This class is deprecated as of July 4, 2024. No need to handle Webhook.
 *
 * Modification Log:
 * Ver   Date         Author               Modification
 * 1.0   03-07-2024   Kankshit Adhaulia    Initial Version
 * 2.0   04-07-2025   Kankshit Adhaulia    Deprecating this class(No need to handle Webhook)
 * *********************************************************
 */
public class StripeEventProcessor implements Queueable, Database.AllowsCallouts {
    private String jsonString;
    private String eventType;

    public StripeEventProcessor(String jsonString, String eventType) {
        this.jsonString = jsonString;
        this.eventType = eventType;
    }

    public void execute(QueueableContext context) {
        StripeEventHandler.handleEvent(jsonString, eventType);
    }
}