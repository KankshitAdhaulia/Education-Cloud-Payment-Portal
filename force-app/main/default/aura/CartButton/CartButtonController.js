({
	doInit : function(component, event, helper) {
        console.log('recordId :: ' , component.get("v.recordId"));
	},
    
    closeAuraComponent: function(component, event, helper) {
        // Close the Aura component
        $A.get("e.force:closeQuickAction").fire(); // Close quick action modal
        $A.get("e.force:refreshView").fire(); // Refresh the view
    }
    
})