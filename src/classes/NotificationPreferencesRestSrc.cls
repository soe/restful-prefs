@RestResource(urlMapping='/v.9/notifications/preferences/*')
global class NotificationPreferencesRestSrc {
    
    @HttpGet
    global static Map<String, String> getMemberNotificationPreferences() {
        String memberName = RestContext.request.params.get('memberName');
        
        // get member's notification settings
        List<Notification_Setting__c> settings = [select Id, Event__c, Member__c, Notification_Method__c from Notification_Setting__c where Member__r.Name = :memberName];
        
        // instantiate prefs map - the map contains all settings a member is supposed to have
        // a member might not have all settings in the database, so make up for those
        Map<String, String> prefs = new Map<String, String>();

        // get Event__c picklist values
        List<Schema.PicklistEntry> events = Notification_Setting__c.getSObjectType()
                                                .getDescribe().fields
                                                .getMap().get('Event__c')
                                                .getDescribe().getPickListValues();
           
        // get categories
        List<Category__c> categories = [select Id, Name from Category__c where Display_on_Site__c = true];
        
        // now build up list of notification settings a member is supposed to have
        // those defined in the Event__c picklist + categories
        
        // loop through picklist values
        for(Schema.PicklistEntry event : events) {
            prefs.put(
                event.getValue(),
                ''
            );
        }
        
        // loop through categories
        for(Category__c category : categories) {
            prefs.put(
                'Category|' + category.Name,
                ''
            );        
        }

        // loop through each notification setting and update prefs
        for(Notification_Setting__c setting : settings) {
            if(setting.Notification_Method__c != 'None') {                
                system.debug(setting.Notification_Method__c);
                system.debug(prefs.keySet());
                // now put it into prefs map, only if the key is valid
                if(prefs.containsKey(setting.Event__c) == True) {
                    prefs.put(
                        setting.Event__c,
                        setting.Notification_Method__c
                    );
                }
                
            }            
        }
        
        return prefs;
    }
    
    @HttpPut
    global static String updateMemberNotificationPreferences() {
        String memberName = RestContext.request.params.get('memberName');
        
        List<Member__c> members = [select Id from Member__c where Name = :memberName];
        
        // only continue if there are at least 1 member
        if(members.size() > 0) {
        
            // delete existing member's notification settings
            List<Notification_Setting__c> settings = [select Id from Notification_Setting__c where Member__r.Name = :memberName];
            delete settings;
            
            // list of settings to be added
            List<Notification_Setting__c> settings_to_insert = new List<Notification_Setting__c>();
            
            // now parse through name value pair
            for(String key : RestContext.request.params.keySet()) {
                if(key == 'memberName') continue;
                
                String methods = RestContext.request.params.get(key);
                
                // then add to list of settings to be added
                if(methods != '') {
                    settings_to_insert.add(
                        new Notification_Setting__c(
                            Event__c = key,
                            Member__c = members[0].Id,
                            Notification_Method__c = methods
                        )
                    );
                }
            }
            
            insert settings_to_insert;
            return 'Member notification settings are successfully updated';
        }
        
        return 'Member does not exist';
        
    }
    
    @isTest
    public static void test_getMemberNotificationPreferences() {
        String baseURI = 'https://'+ System.URL.getSalesforceBaseUrl().getHost() +'/services/apexrest/v.9/notifications/preferences/';
        
        Member__c member = new Member__c(Name = 'soe');
        insert member;
        
        Notification_Setting__c setting1 = new Notification_Setting__c(Member__c = member.Id, Event__c = 'Newsletter', Notification_Method__c = 'Site');
        insert setting1;

        Notification_Setting__c setting2 = new Notification_Setting__c(Member__c = member.Id, Event__c = 'Category|Python', Notification_Method__c = 'Site;Email');
        insert setting2;

        Notification_Setting__c setting3 = new Notification_Setting__c(Member__c = member.Id, Event__c = 'Category|Pascal', Notification_Method__c = 'Site;Email');
        insert setting3;

        Notification_Setting__c setting4 = new Notification_Setting__c(Member__c = member.Id, Event__c = 'Blank', Notification_Method__c = '');
        insert setting4;
                        
        Category__c category1 = new Category__c(Name = 'Ruby', Display_on_Site__c = True);
        insert category1;

        Category__c category2 = new Category__c(Name = 'Python', Display_on_Site__c = False);
        insert category2;
                        
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        RestContext.request.requestURI = baseURI;
        RestContext.request.httpMethod = 'GET';
        RestContext.request.addHeader('Content-Type', 'application/json');
        RestContext.request.params.put('memberName', 'soe');
        
        Map<String, String> prefs = NotificationPreferencesRestSrc.getMemberNotificationPreferences();
        System.assertEquals(prefs.get('Newsletter'), 'Site');
        
        // Display_on_Site__c = False
        System.assertEquals(prefs.containsKey('Category|Python'), False);
                
        // user setting exists in row, but it has become irrelevant, so it shouldn't exists
        System.assertEquals(prefs.containsKey('Category|Pascal'), False);
        
        // blank setting
        System.assertEquals(prefs.get('Category|Ruby'), '');
        
    }

    @isTest
    public static void test_putMemberNotificationPreferences() {
        String baseURI = 'https://'+ System.URL.getSalesforceBaseUrl().getHost() +'/services/apexrest/v.9/notifications/preferences/';
        String msg = '';
        
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
                
        RestContext.request.httpMethod = 'PUT';
        RestContext.request.addHeader('Content-Type', 'application/json');

        RestContext.request.requestURI = baseURI;
        
        msg = NotificationPreferencesRestSrc.updateMemberNotificationPreferences();
        System.assertEquals(msg, 'Member does not exist');


        Member__c member = new Member__c(Name = 'soe');
        insert member;
 
        RestContext.request.params.put('memberName', 'soe');
        RestContext.request.params.put('Category|Python', 'Email;Site'); 
                      
        msg = NotificationPreferencesRestSrc.updateMemberNotificationPreferences();        
        System.assertEquals(msg, 'Member notification settings are successfully updated');
        
        // 1 notification setting for the member
        System.assertEquals([select Id from Notification_Setting__c where Member__r.Id = :member.Id].size(), 1);
                
    }
}