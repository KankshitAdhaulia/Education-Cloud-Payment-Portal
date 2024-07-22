({
    doInit : function(component, event, helper) {
        const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
                mutation.addedNodes.forEach(function(node) {
                    if (node.nodeType === 1) { 
                        if (node.classList.contains('DESKTOP') && node.classList.contains('uiModal') && node.classList.contains('forceModal')) {
                        node.classList.add('slds-hide');
                        observer.disconnect();
                        }
                    }
                });
            });
        });

        const config = { childList: true, subtree: true };
        observer.observe(document.body, config);
    },
    
    closeAuraComponent: function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire(); 
        $A.get("e.force:refreshView").fire(); 
    },
    

})