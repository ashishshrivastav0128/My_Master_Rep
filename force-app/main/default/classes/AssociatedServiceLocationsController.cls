/*   
 * Author Name : Regina;
 * Apex Class Name : AssociatedServiceLocationsController
 * Descriptions : The purpose of the class is used for  PA type creation
 */
public class AssociatedServiceLocationsController {
	
    static User currentUser;
    static{
        currentUser =  [SELECT Profile.Name, ContactId, Contact.Id, AccountId, Account.PID__c FROM User WHERE Id =: UserInfo.getUserId() LIMIT 1];
    }
    
    @AuraEnabled
    public static List<RequestingProviderWrapper> getRequestingProvider(){
        List<Service_Location__c> serviceLocationList = getServiceLocation();
        return fillRequestingProvider(serviceLocationList);
    }
    
    private static List<RequestingProviderWrapper> fillRequestingProvider(List<Service_Location__c> serviceLocationList){
        List<RequestingProviderWrapper>		requestingProviderList = new List<RequestingProviderWrapper>();
        Map<String, String>	typeOfAccessPAMap = getPATypeAccess();
        for(Service_Location__c serviceLocation : serviceLocationList){
                String address = '';
                String providerType = '';
                String optionStr = '';
                if(serviceLocation.DBA_Address_Number_Street__c!=null){
                    address = serviceLocation.DBA_Address_Number_Street__c+' ';
                }
                if(serviceLocation.DBA_Address_City__c!=null){
                    address += serviceLocation.DBA_Address_City__c+' ';
                }
                if(serviceLocation.DBA_Address_State__c!=null){
                    address +=  serviceLocation.DBA_Address_State__c+' ';
                }
                if(serviceLocation.DBA_Address_Zip_Code__c!=null){
                    address += serviceLocation.DBA_Address_Zip_Code__c;
                }
                if(serviceLocation.Provider_Type__c!=null){
                    providerType = (serviceLocation.Provider_Type__c).substringBeforeLast('(');    
                }
                if(serviceLocation.PID_SL__c!='' && serviceLocation.PID_SL__c!=null){
                    optionStr = serviceLocation.PID_SL__c +' - '; 
                }
                if(serviceLocation.Trade_Doing_Business_As_DBA_Name__c!='' && serviceLocation.Trade_Doing_Business_As_DBA_Name__c!=null){
                    optionStr += serviceLocation.Trade_Doing_Business_As_DBA_Name__c+' - ';
                }
                if(address!='' && address!=null){
                    optionStr +=address +' - ';
                }
                if(optionStr!='' && optionStr!=null){
                    optionStr += providerType;
                }else{
                    optionStr.removeEnd('-');
                }
                if(typeOfAccessPAMap.containsKey(serviceLocation.Provider_Type__c)){
                    RequestingProviderWrapper requestingProvider = new RequestingProviderWrapper();
                    requestingProvider.label = optionStr;
                    requestingProvider.value = serviceLocation.Id;
                    requestingProviderList.add(requestingProvider);
                }
            }
        
        return requestingProviderList;
    }
    
    Private Static Map<String, String> getPATypeAccess(){
        System.debug('hello user => '+  currentUser);
        System.debug('hello user => '+  currentUser.Account.PID__c);
        Boolean migrationInProgress = false;
        List<String> migratedPIDSls = new List<String>();
        List<Provider__c> providerList = [SELECT Id, Migration_Ready__c, Migration_Status__c, Migrated_PIDSL__c FROM Provider__c WHERE Id =: currentUser.Account.PID__c  LIMIT 1];
        Provider__c providerItem;
        if(providerList.size() > 0){
            providerItem = providerList[0];
            if(String.isNotBlank(providerItem.Migrated_PIDSL__c)) {
                migratedPIDSls.addAll(providerItem.Migrated_PIDSL__c.split(';'));
            }
            migrationInProgress = providerItem.Migration_Status__c == 'In Progress' ? true : false;
        }
        
        Map<String, String>	typeOfAccessPAMap = new Map<String, String>();
        
        List<PA_Type_Access__mdt> typeOfAccessPAList = [SELECT PA_Type__c, Provider_Type__c, Available_to_End_user__c FROM PA_Type_Access__mdt 
                                                        WHERE Available_to_End_user__c = True];
        
        for(PA_Type_Access__mdt typeOfAccessPA : typeOfAccessPAList){
            
             if(migrationInProgress){
                if(migratedPIDSls.contains(typeOfAccessPA.PA_Type__c)){
                   typeOfAccessPAMap.put(typeOfAccessPA.Provider_Type__c, typeOfAccessPA.PA_Type__c);
                }
            }else{
                  typeOfAccessPAMap.put(typeOfAccessPA.Provider_Type__c, typeOfAccessPA.PA_Type__c);
            }
        }
        return typeOfAccessPAMap;
    }
    
    
    private Static List<Service_Location__c> getServiceLocation(){
        List<Service_Location__c> serviceLocationList = new List<Service_Location__c>();
        Id accountId = currentUser.AccountId;
        Id providerId;
        if(currentUser != NULL && currentUser.ContactId != NULL && Schema.sObjectType.Contact.isAccessible()){
            providerId = currentUser.Account.PID__c;
        }
        if(accountId != null){
            if(LTSSUtilities.IsNewSecondaryUser(currentUser)){
                
                serviceLocationList = [SELECT Id, PID_SL__c, Trade_Doing_Business_As_DBA_Name__c, Provider_Type__c, DBA_Address_Building_or_Suite__c,  DBA_Address_Number_Street__c, DBA_Address_City__c, DBA_Address_State__c, DBA_Address_Zip_Code__c FROM Service_Location__c 
      								   WHERE Id IN (SELECT Service_Location__c FROM Account_ServiceLocation__c WHERE Account__c =:accountId AND PA_write_access__c = True) AND 
      								   PID_SL__C != null AND (Enrollment_Status_Code__c='LTSS Provider Types Only 26' OR Enrollment_Status_Code__c LIKE '%active%' OR Enrollment_Status_Code__c LIKE :'%'+GlobalConstants.REVIEW_ALL_CLAIMS_PENDED+'%') ORDER BY PID_SL__c];
            }else{
               serviceLocationList = [SELECT Id, PID_SL__c, Trade_Doing_Business_As_DBA_Name__c, Provider_Type__c, DBA_Address_Number_Street__c, DBA_Address_City__c,
       								 DBA_Address_State__c, DBA_Address_Zip_Code__c FROM Service_Location__c  WHERE PID__c =: providerId AND PID_SL__c != null
       								 AND (Enrollment_Status_Code__c='LTSS Provider Types Only 26' OR Enrollment_Status_Code__c LIKE '%active%' 
                                     OR Enrollment_Status_Code__c LIKE :'%'+GlobalConstants.REVIEW_ALL_CLAIMS_PENDED+'%') ORDER BY PID_SL__c];
            }
        }
        return serviceLocationList;
    }
    
    
    public class RequestingProviderWrapper{
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}