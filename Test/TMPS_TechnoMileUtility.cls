/**
 * @description       : Utility class for TechnoMile PS Custom Processes
 * @author            : Sean Upton - sean.upton@technomile.com
 * @group             : 
 * @last modified on  : 05-23-2023
 * @last modified by  : Sean Upton - sean.upton@technomile.com
 * Modifications Log
 * Ver   Date         Author                                   Modification
 * 1.0   03-23-2023   Sean Upton - sean.upton@technomile.com   Initial Version
**/
public without sharing class TMPS_TechnoMileUtility {
    public static Boolean isFirstRun = false;
    public Boolean isInsert;
    public List<tmps_TechnoMile_Data_Mappings__mdt> fieldMappings;
    public List<TMPS_TechnoMile_Error_Log__c> errorLogsList               = new List<TMPS_TechnoMile_Error_Log__c>();
    public Map<String, TM_TOMA__Contract_Vehicle__c> contractParentMap    = new Map<String, TM_TOMA__Contract_Vehicle__c>();
    public Set<String> parentProjectNumbers                               = new Set<String>();
    public Map<String, TM_TOMA__Contract_Vehicle__c> existingContractsMap = new Map<String, TM_TOMA__Contract_Vehicle__c>();
    public Map<String, Account> customerIdToAccountMap                    = new Map<String, Account>();
    public List<Costpoint_Project__c> projectsToUpdate                    = new List<Costpoint_Project__c>();
    public Map<String, Costpoint_Project__c> cpNumToProjectMap            = new Map<String, Costpoint_Project__c>();
    public Map<Id, CAN__c> canMap                                         = new Map<Id, CAN__c>();
    public Map<String,Schema.RecordTypeInfo> rtMapByName                  = Schema.SObjectType.TM_TOMA__Contract_Vehicle__c.getRecordTypeInfosByName();

    public Map<String, String> GSAScheduleNameToNumberMap = new Map<String, String>{
        'FSS 874.3 (0097L)'    => '0208018',
        'FSS 899.1 (0283K)'    => '0208080',
        'FSS 871.4    (0147N)' => '0208760',
        'FSS 874.1 (0097L)'    => '0208813',
        'FSS 873.2 (097F)'     => '0209520',
        'FSS 899.1 (0283K)'    => '0209606',
        'SIN 132-51 (0829R)'   => '0209887',
        'FSS 541-4A (0112U)'   => '0211512',
        'FSS 874-1 (0311M)'    => '0212772',
        'FSS 873-2 [0284X]'    => '0212945',
        'IT70 132-51 (236AA)'  => '0213905',
        'OASIS - Pool 2'       => '0214560',
        'PSS 874-1 (354CA)'    => '0215000',
        'OASIS - Pool 4'       => '0217801',
        'OASIS - Pool 1'       => '0218015',
        'PSS 541611 (354CA)'   => '0215000'
    };

//     FSS 874.3 (NON-GSA) this is not GSA and should be ignored in creation of parent/child
//     PSS 541-5 (354CA)  is 0211512
//     PSS 541611 (354CA) and PSS 541620 (354CA) are 0215000
//     PSS 899-1 (354CA) is 0208080
//     FSS 874.1 (0097L) should map to 0208018 and not 0208813

    // Removed this schedule value per call on 5/10/2023
    // 'FSS 899.1 (0283K)'    => '0210288',

    public TMPS_TechnoMileUtility() {

    }

    /**
    * @description Retrieves field mappings from custom metadata based on the syncType (All, Project, Contract)
    * @author Sean Upton - sean.upton@technomile.com | 05-18-2023 
    * @param String syncType 
    * @return List<tmps_TechnoMile_Data_Mappings__mdt> 
    **/
    public List<tmps_TechnoMile_Data_Mappings__mdt> getFieldMappings(String syncType){
        String query = 'SELECT Id, Contract_Field__c, Project_Field__c FROM tmps_TechnoMile_Data_Mappings__mdt ';

        switch on syncType {
            when 'Project' {
                query += 'WHERE tmps_Sync_to_Project__c = TRUE';
            }
            when 'Contract' {
                query += 'WHERE Sync_to_Contract__c = TRUE';
            }
            when else {
                // leave empty for All
            }
        }
        return Database.query(query);
    }

    /**
    * @description Syncs data with existing Contracts when Costpoint Data is updated
    * @author Sean Upton - sean.upton@technomile.com | 05-21-2023 
    * @param List<Costpoint_Project__c> newProjects 
    * @param Map<Id Costpoint_Project__c> oldProjects 
    **/
    public void syncWithContracts(List<Costpoint_Project__c> newProjects, Map<Id, Costpoint_Project__c> oldProjects){
        List<TM_TOMA__Contract_Vehicle__c> contractsToUpdate = new List<TM_TOMA__Contract_Vehicle__c>();
        fieldMappings = getFieldMappings('Contract');
        
        getRelatedData(newProjects);
        for (Costpoint_Project__c project : newProjects){
            // If update operation and show in salesforce was already true
            if (oldProjects != null 
                && oldProjects.get(project.Id) != null
                && oldProjects.get(project.Id).Show_in_Salesforce__c == true
                && project.Show_in_Salesforce__c == true)
            {
                try {
                    TM_TOMA__Contract_Vehicle__c contract = new TM_TOMA__Contract_Vehicle__c(Id = project.tmps_TechnoMile_Contract__c);
                    cpNumToProjectMap.put(project.Name, project);

                    if (!existingContractsMap.containsKey(project.Name) ){
                        errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(tmps_Project__c = project.Id, tmps_Error_Details__c = 'A Contract could not be found for update with Project Number: ' + project.Name, tmps_Process_Type__c = 'Contract Updates'));
                        continue;
                    }

                    //Loop over field mappings in the Custom Metadata to set field values which do not require transformation.
                    for (tmps_TechnoMile_Data_Mappings__mdt fieldMapping : fieldMappings)
                    {
                        //Only update fields which were modified in the transaction
                        if (project.get(fieldMapping.Project_Field__c) != oldProjects.get(project.Id).get(fieldMapping.Project_Field__c)){
                            System.debug('+++ Project Field: ' + fieldMapping.Project_Field__c + ' :::: Contract Field: ' + fieldMapping.Contract_Field__c);
                            // Example evaluation: contract.put('tmps_Costpoint_Project_Number__c', project.get('Costpoint_Project_Num__c'));
                            contract.put(fieldMapping.Contract_Field__c, project.get(fieldMapping.Project_Field__c));
                        }
                    }

                    if (project.Customer_ID__c != oldProjects.get(project.Id).Customer_ID__c){
                        contract.TM_TOMA__Account_Name__c = customerIdToAccountMap.containsKey(project.Customer_ID__c) ? customerIdToAccountMap.get(project.Funding_Source_ID__c).Id : null;
                    }

                    if (project.Funding_Source_ID__c != oldProjects.get(project.Id).Funding_Source_ID__c){
                        contract.TM_TOMA__End_User_Organization__c = customerIdToAccountMap.containsKey(project.Funding_Source_ID__c) ? customerIdToAccountMap.get(project.Funding_Source_ID__c).Id : null;
                    }
                    
                    contract.tmps_CP_Data_Updated__c = true; //used for triggering a notification that CostPoint data has been synced from the Project record.

                    if (project.Master_IDIQ_Project__c != oldProjects.get(project.Id).Master_IDIQ_Project__c
                        || project.GSA_Schedule__c != oldProjects.get(project.Id).GSA_Schedule__c)
                    {
                        contract = setRecordTypeAndParent(project, contract);
                    }
                    
                    if (contract != null){
                        contractsToUpdate.add(contract);
                    }

                } catch (Exception ex) {
                    System.debug(System.LoggingLevel.ERROR, '+++ An exception was encountered during Contract Updates: ' + ex);
                    System.debug(System.LoggingLevel.ERROR, '+++: ' + ex.getStackTraceString());
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(tmps_Project__c = project.Id, tmps_Error_Details__c = ex.getMessage() + '\n' +  + ex.getStackTraceString(), tmps_Process_Type__c = 'Contract Updates'));
                }

                List<Id> updatedContractIds = new List<Id>();
                Boolean errorFound = false;
                String possibleCauses = '';

                if (!contractsToUpdate.isEmpty()){
                    try {
                        Database.SaveResult[] contractResults = Database.update(contractsToUpdate, false);
                    
                        for (Database.SaveResult result : contractResults){
                            possibleCauses = '';
                            if(result.isSuccess()) {
                                Id contractId = result.getId();
                                System.debug('+++ Contract updated successfully: ' + result.getId());
                            } 
                            else {
                                errorFound = true;
                                for(Database.Error err : result.getErrors()) {           
                                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                                    System.debug('Contract fields that affected this error: ' + err.getFields());
                                    String error = ' Field: ' + err.getFields() + '-' + err.getMessage();
                                    possibleCauses += (possibleCauses == '') ? error : ' || ' + error;
                                }
                            }
                        }
                    } catch (Exception ex) {
                        System.debug(System.LoggingLevel.ERROR, '+++ An exception was encountered during Contract Initiation: ' + ex);
                        
                        //TODO: Enhance with Database.insert to log errors.
                    }
                }
            }
        }

        if (!errorLogsList.isEmpty()){
            System.debug('++++ errorLogsList ' + errorLogsList);
            insert errorLogsList;
        }
        
    }


    //TODO: Costpoint Customer table
    /**
    * @description 
    * @author Sean Upton - sean.upton@technomile.com | 04-26-2023 
    * @param List<Costpoint_Project__c> newProjects 
    * @param Map<Id Costpoint_Project__c> oldProjects 
    * @return List<TM_TOMA__Contract_Vehicle__c> 
    **/
    public void createContracts(List<Costpoint_Project__c> newProjects, Map<Id, Costpoint_Project__c> oldProjects){
        List<TM_TOMA__Contract_Vehicle__c> contractsToInsert = new List<TM_TOMA__Contract_Vehicle__c>();
        fieldMappings = getFieldMappings('ALL');
        
        getRelatedData(newProjects);

        for (Costpoint_Project__c project : newProjects){
            // if Show_in_Salesforce__c = true and either it's a new record or the value has change from false
            if (project.Show_in_Salesforce__c == true
                && project.tmps_TechnoMile_Contract__c == null
                && (isInsert 
                    || (oldProjects.get(project.Id) != null 
                        && oldProjects.get(project.Id).Show_in_Salesforce__c == false)))
                
            {
                try {
                    TM_TOMA__Contract_Vehicle__c contract = new TM_TOMA__Contract_Vehicle__c();
                    cpNumToProjectMap.put(project.Name, project);

                    // Throw errors for some validations prior to running the rest of the code
                    if (existingContractsMap.containsKey(project.Name) ){
                        errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(tmps_Project__c = project.Id, tmps_Error_Details__c = 'A Contract already exists for this Project Number: ' + project.Name, tmps_Process_Type__c = 'Contract Initiation'));
                        continue;
                    }
                
                    //Loop over field mappings in the Custom Metadata to set field values which do not require transformation.
                    for (tmps_TechnoMile_Data_Mappings__mdt fieldMapping : fieldMappings)
                    {
                        System.debug('Project Field: ' + fieldMapping.Project_Field__c + ' :::: Contract Field: ' + fieldMapping.Contract_Field__c);
                        // Example evaluation: contract.put('tmps_Costpoint_Project_Number__c', project.get('Costpoint_Project_Num__c'));
                        contract.put(fieldMapping.Contract_Field__c, project.get(fieldMapping.Project_Field__c));
                    }
                    
                    //Start derived field logic
                    switch on project.Status__c {
                        when 'Active' {
                            contract.TM_TOMA__Contract_Status__c = 'Initiated';
                        }
                        when 'Stop Work' {
                            contract.TM_TOMA__Contract_Status__c = 'Stop Work';
                        }
                        when 'Closed' {
                            contract.TM_TOMA__Contract_Status__c = 'Closed';
                        }
                        when else {
                            //
                        }
                    }

                    // Validate data was mapped for some fields
                    contract.tmps_can_no_can__c = isInsert ? 'CAN' : 'No CAN';
                    if (project.Contract_Manager__c == null){
                        errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(tmps_Project__c = project.Id, tmps_Error_Details__c = 'Contract Manager was not provided for the Contract.', tmps_Process_Type__c = 'Contract Initiation'));
                        continue;
                    }

                    contract.tmps_Billing_Address__c = project.Billing_Address_Part_1__c + ', ' + project.Billing_Address_Part_2__c;
                    
                    contract.TM_TOMA__Account_Name__c = project.Customer_ID__c != null && customerIdToAccountMap.containsKey(project.Customer_ID__c)       
                                                        ? customerIdToAccountMap.get(project.Customer_ID__c).Id 
                                                        : null;
                    contract.TM_TOMA__End_User_Organization__c = project.Funding_Source_ID__c != null && customerIdToAccountMap.containsKey(project.Funding_Source_ID__c) 
                                                                ? customerIdToAccountMap.get(project.Funding_Source_ID__c).Id 
                                                                : null;
                    
                    

                    //retrieve values from related CAN record if it exists
                    //TODO: test if this can be moved to the custom metadata mapping
                    if (project.CAN__c != null && canMap.containsKey(project.CAN__c)){
                        CAN__c can = canMap.get(project.CAN__c);
                        contract.tmps_Fixed_Fee__c                          = can.Fixed_Fee_FAR_52_216_8__c;
                        contract.tmps_PS_Milestone_Billing__c               = can.Payment_Schedule_or_Milestone_Billings__c;
                        contract.tmps_Location_of_Payment_Schedule__c       = can.Location_of_Payment_Schedule__c;
                        contract.tmps_Requires_Additional_Receipts__c       = can.Requires_Additional_Receipts__c;
                        contract.tmps_Requires_Additional_Receipts_Other__c = can.Requires_Addtional_Receipts_Other__c;
                        contract.tmps_Reimburse_Contract__c                 = can.reimburse_the_customer_for_funds_not_spe__c;
                        contract.tmps_labor_cat_rate_ceiling__C             = can.Labor_Category_Rate_Ceiling__c;
                        contract.tmps_Labor_Cat_Rate_Ceiling_Details__c     = can.Labor_Category_Rate_Ceilings_Details__c;
                        contract.tmps_How_are_Subs_Consultants_Billed__c    = can.How_are_Subs_Consultants_Billed__c;
                        contract.tmps_Premium_Time_Billable__c              = can.Premium_Time_Billable__c;
                        contract.tmps_invoice_frequency__c                  = can.Invoice_Frequency__c;

                    }

                    //Can we please populate the “Project Name” field in TechnoMile with the “Alternate Project Title” in the CAN (if there is a CAN).  If there is no CAN, this field can be blank in TM.  This field should be editable in TechnoMile and should be sent back to the “Project Long Name” field on the Project Record in Salesforce.

                    //@Sean Upton Can we please populate the “Project Name” field in TechnoMile with the “Opportunity Name” on the CAN (if there is a CAN).  If there is no CAN, this field can be blank in TM.  This field should be editable in TechnoMile and should be sent back to the “Project Long Name” field on the Project Record in Salesforce.

                    contract = setRecordTypeAndParent(project, contract);
                    if (contract != null){
                        contractsToInsert.add(contract);
                    }
                    
                } catch (Exception ex) {
                    System.debug(System.LoggingLevel.ERROR, '+++ An exception was encountered during Contract Initiation: ' + ex);
                    System.debug(System.LoggingLevel.ERROR, '+++: ' + ex.getStackTraceString());
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(tmps_Project__c = project.Id, tmps_Error_Details__c = ex.getMessage() + '\n' +  + ex.getStackTraceString(), tmps_Process_Type__c = 'Contract Initiation'));
                }
            }
        }

        List<Id> insertedContractIds = new List<Id>();
        List<Costpoint_Project__c> projectsToUpdate = new List<Costpoint_Project__c>();
        Boolean errorFound = false;
        String possibleCauses = '';

        if (!contractsToInsert.isEmpty()){
            try {
                Database.SaveResult[] contractResults = Database.insert(contractsToInsert, false);
                
                contractsToInsert.clear(); //TODO: remove
                for (Database.SaveResult result : contractResults){
                    possibleCauses = '';
                    if(result.isSuccess()) {
                        Id contractId = result.getId();
                        System.debug('+++ Contract inserted successfully: ' + result.getId());
                        insertedContractIds.add(contractId);
                    } 
                    else {
                        errorFound = true;
                        for(Database.Error err : result.getErrors()) {     
                            //TODO: Enhance with log entry      
                            System.debug(err.getStatusCode() + ': ' + err.getMessage());
                            System.debug('Contract fields that affected this error: ' + err.getFields());
                            String error = ' Field: ' + err.getFields() + '-' + err.getMessage();
                            possibleCauses += (possibleCauses == '') ? error : ' || ' + error;
                        }
                    }
                }
                if (!insertedContractIds.isEmpty()){
                    List<TM_TOMA__Contract_Vehicle__c> insertedContracts = [SELECT Id, Name FROM TM_TOMA__Contract_Vehicle__c WHERE Id IN: insertedContractIds];
                    for (TM_TOMA__Contract_Vehicle__c contract : insertedContracts){
                        Costpoint_Project__c project = new Costpoint_Project__c(Id = cpNumToProjectMap.get(contract.Name).Id, tmps_TechnoMile_Contract__c = contract.Id) ;
                        projectsToUpdate.add(project);
                    }
                }
            } catch (Exception ex) {
                System.debug(System.LoggingLevel.ERROR, '+++ An exception was encountered during Contract Initiation: ' + ex);
                
                //TODO: Enhance with Database.insert to log errors.
            }
        }

        if (!projectsToUpdate.isEmpty()){
            update projectsToUpdate;
            projectsToUpdate.clear(); //TODO: remove
        }

        if (!errorLogsList.isEmpty()){
            System.debug('++++ errorLogsList ' + errorLogsList);
            insert errorLogsList;
            errorLogsList.clear(); //TODO: remove
        }
    }

    /**
    * @description Determine Record Type & parents based on Master_IDIQ_Project__c, GSA_Schedule__c, Contract_Type__c
    * @author Sean Upton - sean.upton@technomile.com | 05-11-2023 
    * @param TM_TOMA__Contract_Vehicle__c contract 
    * @return TM_TOMA__Contract_Vehicle__c 
    **/
    private TM_TOMA__Contract_Vehicle__c setRecordTypeAndParent(Costpoint_Project__c project, TM_TOMA__Contract_Vehicle__c contract) {
        if (project.Customer_Name__c != 'GSA'){
                // Order within an IDIQ
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c != project.Name 
                && project.GSA_Schedule__c != null
                && project.Contract_Type__c != 'BOA')
            {
                System.debug('+++ Order RT under IDIQ');
                contract.RecordTypeId = rtMapByName.get('Order').getRecordTypeId();
                if (!contractParentMap.containsKey(project.Master_IDIQ_Project__c)){
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(
                                tmps_Project__c = project.Id, 
                                tmps_Error_Details__c = 'Parent IDIQ Contract does not exist for Costpoint Project #: ' + project.Master_IDIQ_Project__c, 
                                tmps_Process_Type__c = 'Contract Initiation'
                                ));
                    return null;
                } else {
                    contract.TM_TOMA__Master_Contract_Vehicle__c = contractParentMap.get(project.Master_IDIQ_Project__c).Id;
                }
            }

            // Order under an GSA
            if (project.Master_IDIQ_Project__c == null 
                && project.GSA_Schedule__c != null
                && project.Contract_Type__c != 'BOA')
            {
                System.debug('+++ Order RT under GSA');
                contract.RecordTypeId = rtMapByName.get('Order').getRecordTypeId();
                if (!GSAScheduleNameToNumberMap.containsKey(project.GSA_Schedule__c)
                    || !contractParentMap.containsKey(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)))
                {
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(
                        tmps_Project__c = project.Id, 
                        tmps_Error_Details__c = 'Parent GSA Contract does not exist for Costpoint Project #: ' + project.GSA_Schedule__c, 
                        tmps_Process_Type__c = 'Contract Initiation'
                        ));
                    return null;
                } else {
                    contract.TM_TOMA__Master_Contract_Vehicle__c = contractParentMap.get(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)).Id;
                }
            }

            // Definitive
            if (project.Master_IDIQ_Project__c == null
                && project.GSA_Schedule__c == null
                && project.Contract_Type__c != 'BOA')
            {
                System.debug('+++ Definitive RT');
                contract.RecordTypeId = rtMapByName.get('Definitive').getRecordTypeId();
            }

            // IDIQ without parent
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c == project.Name 
                && project.GSA_Schedule__c == null
                && project.Contract_Type__c == 'BOA')
            {
                System.debug('+++ IDIQ RT without parent');
                contract.RecordTypeId = rtMapByName.get('IDIQ').getRecordTypeId();
            }

            // IDIQ under GSA
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c == project.Name 
                && project.GSA_Schedule__c != null
                && project.Contract_Type__c == 'BOA')
            {
                System.debug('+++ IDIQ RTunder GSA');
                contract.RecordTypeId = rtMapByName.get('IDIQ').getRecordTypeId();
                if (!GSAScheduleNameToNumberMap.containsKey(project.GSA_Schedule__c)
                    || !contractParentMap.containsKey(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)))
                {
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(
                        tmps_Project__c = project.Id, 
                        tmps_Error_Details__c = 'Parent GSA Contract does not exist for Costpoint Project #: ' + project.GSA_Schedule__c, 
                        tmps_Process_Type__c = 'Contract Initiation'
                        ));
                    return null;
                } else {
                    contract.TM_TOMA__Master_Contract_Vehicle__c = contractParentMap.get(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)).Id;
                }
            }

            //Sprint 3 Additions
            // IDIQ within an IDIQ
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c != project.Name 
                && project.GSA_Schedule__c == null
                && project.Contract_Type__c == 'BOA')
            {
                System.debug('+++ IDIQ RT under IDIQ');
                contract.RecordTypeId = rtMapByName.get('IDIQ').getRecordTypeId();
                if (!contractParentMap.containsKey(project.Master_IDIQ_Project__c)){
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(
                                tmps_Project__c = project.Id, 
                                tmps_Error_Details__c = 'Parent IDIQ Contract does not exist for Costpoint Project #: ' + project.Master_IDIQ_Project__c, 
                                tmps_Process_Type__c = 'Contract Initiation'
                                ));
                    return null;
                } else {
                    contract.TM_TOMA__Master_Contract_Vehicle__c = contractParentMap.get(project.Master_IDIQ_Project__c).Id;
                }
            }

            // IDIQ without a parent
            if (project.Master_IDIQ_Project__c == null 
                && project.GSA_Schedule__c == null
                && project.Contract_Type__c == 'BOA')
            {
                
                System.debug('+++ IDIQ RT without parent');
                contract.RecordTypeId = rtMapByName.get('IDIQ').getRecordTypeId();
            }

            //IDIQ under a GSA Schedule
            if (project.Master_IDIQ_Project__c == null 
                && project.GSA_Schedule__c != null
                && project.Contract_Type__c == 'BOA')
            {
                contract.RecordTypeId = rtMapByName.get('IDIQ').getRecordTypeId();
                if (!GSAScheduleNameToNumberMap.containsKey(project.GSA_Schedule__c)
                    || !contractParentMap.containsKey(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)))
                {
                    System.debug('+++ IDIQ RT under GSA Schedule');
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(
                        tmps_Project__c = project.Id, 
                        tmps_Error_Details__c = 'Parent GSA Contract does not exist for Costpoint Project #: ' + project.GSA_Schedule__c, 
                        tmps_Process_Type__c = 'Contract Initiation'
                        ));
                    return null;
                } else {
                    contract.TM_TOMA__Master_Contract_Vehicle__c = contractParentMap.get(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)).Id;
                }
            }

            // Definitive
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c == project.Name 
                && project.GSA_Schedule__c == null
                && project.Contract_Type__c != 'BOA')
            {
                System.debug('+++ Definitive RT');
                contract.RecordTypeId = rtMapByName.get('Definitive').getRecordTypeId();
            }

            //Order under a GSA Schedule
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c == project.Name 
                && project.GSA_Schedule__c != null
                && project.Contract_Type__c != 'BOA')
            {
                System.debug('+++ Order RT under GSA Schedule');
                contract.RecordTypeId = rtMapByName.get('Order').getRecordTypeId();
                if (!GSAScheduleNameToNumberMap.containsKey(project.GSA_Schedule__c)
                    || !contractParentMap.containsKey(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)))
                {
                    errorLogsList.add(new TMPS_TechnoMile_Error_Log__c(
                        tmps_Project__c = project.Id, 
                        tmps_Error_Details__c = 'Parent GSA Contract does not exist for Costpoint Project #: ' + project.GSA_Schedule__c, 
                        tmps_Process_Type__c = 'Contract Initiation'
                        ));
                    return null;
                } else {
                    contract.TM_TOMA__Master_Contract_Vehicle__c = contractParentMap.get(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)).Id;
                }
            }
        } else {
            // GSA Schedule
            if (project.Master_IDIQ_Project__c != null 
                && project.Master_IDIQ_Project__c == project.Name 
                && project.GSA_Schedule__c == null
                && project.Contract_Type__c == 'BOA')
            {
                System.debug('+++ GSA / IDIQ RT');
                contract.RecordTypeId = rtMapByName.get('IDIQ').getRecordTypeId();
            }
        }
        
        return contract;
    }

    /**
    * @description Bulkified method for retrieving all related CAN records for a given set of Projects
    * @author Sean Upton - sean.upton@technomile.com | 04-27-2023 
    * @param List<Costpoint_Project__c> newProjects 
    * @return Map<Id, CAN__c> 
    **/
    // public Map<Id, CAN__c> getRelatedCANRecords(List<Costpoint_Project__c> newProjects){
    //     for (Costpoint_Project__c project : newProjects){
    //         // if 
    //     }
    // }
    private void getRelatedData(List<Costpoint_Project__c> newProjects){
        Set<String> projectNumbers = new Set<String>();
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> canIds = new Set<Id>();
        Set<String> customerIds = new Set<String>();


        for (Costpoint_Project__c project : newProjects){
            if (project.Master_IDIQ_Project__c != null){
                parentProjectNumbers.add(project.Master_IDIQ_Project__c);
            }

            if (project.GSA_Schedule__c != null){
                System.debug('+++ GSA SCHEDULE INFO:  project.GSA_Schedule__c:' + project.GSA_Schedule__c + ' GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c)' + GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c));
                parentProjectNumbers.add(GSAScheduleNameToNumberMap.get(project.GSA_Schedule__c));
            }

            if (project.CAN__c != null){
                canIds.add(project.CAN__c);
            }

            //TM_TOMA__End_User_Organization__c
            if (project.Funding_Source_ID__c != null){
                customerIds.add(project.Funding_Source_ID__c);
            }

            if (project.Customer_ID__c != null){
                customerIds.add(project.Customer_ID__c);
            }
            
            projectNumbers.add(project.Name);
        }

        //TODO: Roll the below queries into one query
        for (TM_TOMA__Contract_Vehicle__c contract : [SELECT Id, tmps_costpoint_project_num__c, tmps_Project_Manager__c FROM TM_TOMA__Contract_Vehicle__c WHERE tmps_costpoint_project_num__c IN: parentProjectNumbers])
        {
            contractParentMap.put(contract.tmps_costpoint_project_num__c, contract);
        }

        for (TM_TOMA__Contract_Vehicle__c contract : [SELECT Id, tmps_costpoint_project_num__c, tmps_Project_Manager__c FROM TM_TOMA__Contract_Vehicle__c WHERE tmps_costpoint_project_num__c IN: projectNumbers])
        {
            existingContractsMap.put(contract.tmps_costpoint_project_num__c, contract);
        }

        // for Funding Source and Customer Name
        for (Account acc : [SELECT Id, Customer_ID__c FROM Account WHERE Customer_ID__c IN: customerIds])
        {
            customerIdToAccountMap.put(String.valueOf(acc.Customer_ID__c), acc);
        }

        for (CAN__c can : [SELECT Id, 
                            Fixed_Fee_FAR_52_216_8__c,
                            Payment_Schedule_or_Milestone_Billings__c,
                            Location_of_Payment_Schedule__c,
                            Alternate_Project_Title__c, 
                            OpportunityName__c, 
                            Requires_Addtional_Receipts_Other__c, 
                            reimburse_the_customer_for_funds_not_spe__c, 
                            Labor_Category_Rate_Ceiling__c, 
                            Labor_Category_Rate_Ceilings_Details__c, 
                            How_are_Subs_Consultants_Billed__c, 
                            Premium_Time_Billable__c, 
                            Invoice_Frequency__c
            FROM CAN__c WHERE Id IN: canIds])
        {
                canMap.put(can.Id, can);
        }

    }

}