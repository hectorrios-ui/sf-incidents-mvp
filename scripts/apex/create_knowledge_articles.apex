/**
 * Anonymous Apex — Run AFTER enabling Salesforce Knowledge in the org.
 *
 * Pre-requisites (do these first in Setup):
 *  1. Setup → Knowledge Settings → Enable Lightning Knowledge → Save
 *  2. Setup → Profiles → your profile → Enable "Manage Articles" + "Read" on Knowledge
 *  3. Deploy NF_Accelerator__c with the Knowledge_Article_URL__c field
 *
 * Run via:
 *   sf apex run --file scripts/apex/create_knowledge_articles.apex -o <your-org-alias>
 */

// ── Guard ─────────────────────────────────────────────────────────────────────
if (!Schema.getGlobalDescribe().containsKey('Knowledge__kav')) {
    System.debug('ERROR: Knowledge__kav not found. Enable Lightning Knowledge in Setup first.');
    return;
}

// ── 1. Fetch accelerators without articles ────────────────────────────────────
List<NF_Accelerator__c> accs = [
    SELECT Id, Name, Description__c, Tags__c, Cloud__c, Industry__c,
           Asset_Owner__c, Complexity__c, Source__c, Source_URL__c,
           Estimated_Hours_Saved__c
    FROM NF_Accelerator__c
    WHERE Knowledge_Article_URL__c = null
      AND Quality_Badge__c != 'Deprecated'
    ORDER BY Name
];

System.debug('Accelerators to process: ' + accs.size());
if (accs.isEmpty()) {
    System.debug('Nothing to do — all accelerators already have a Knowledge Article linked.');
    return;
}

// ── 2. Build and insert draft articles ───────────────────────────────────────
Schema.SObjectType kavType = Schema.getGlobalDescribe().get('Knowledge__kav');
List<SObject> drafts      = new List<SObject>();
Map<String, Id> nameToAccId = new Map<String, Id>();

for (NF_Accelerator__c a : accs) {
    SObject art = kavType.newSObject();
    art.put('Title',   a.Name);
    art.put('UrlName', toUrlName(a.Name));
    art.put('Summary', a.Description__c != null && a.Description__c.length() > 255
                         ? a.Description__c.substring(0, 252) + '...'
                         : (a.Description__c != null ? a.Description__c : a.Name));
    drafts.add(art);
    nameToAccId.put(a.Name, a.Id);
}

insert drafts;
System.debug('Inserted ' + drafts.size() + ' draft Knowledge articles.');

// ── 3. Re-query drafts to get KnowledgeArticleId (master object ID) ───────────
//    publishArticle() requires the MASTER KnowledgeArticle Id, not the version Id.
Set<Id> versionIds = new Map<Id, SObject>(drafts).keySet();
List<SObject> draftsWithKaId = Database.query(
    'SELECT Id, KnowledgeArticleId, Title FROM Knowledge__kav WHERE Id IN :versionIds'
);

// ── 4. Publish each article ───────────────────────────────────────────────────
Map<String, Id> titleToKaId = new Map<String, Id>();
for (SObject d : draftsWithKaId) {
    Id kaId = (Id) d.get('KnowledgeArticleId');
    titleToKaId.put((String) d.get('Title'), kaId);
    KbManagement.PublishingService.publishArticle(kaId, true);
}
System.debug('Published ' + titleToKaId.size() + ' articles.');

// ── 5. Write article URLs back to NF_Accelerator__c ──────────────────────────
String orgUrl = System.URL.getOrgDomainURL().toExternalForm();

List<NF_Accelerator__c> toUpdate = new List<NF_Accelerator__c>();
for (String title : titleToKaId.keySet()) {
    Id accId = nameToAccId.get(title);
    Id kaId  = titleToKaId.get(title);
    if (accId != null && kaId != null) {
        toUpdate.add(new NF_Accelerator__c(
            Id = accId,
            Knowledge_Article_URL__c = orgUrl + '/lightning/r/KnowledgeArticle/' + kaId + '/view'
        ));
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Linked ' + toUpdate.size() + ' Knowledge Articles to NF_Accelerator__c records.');
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String toUrlName(String title) {
    String slug   = title.toLowerCase().replaceAll('[^a-z0-9]+', '-').replaceAll('(^-|-$)', '');
    String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).left(4);
    return slug.left(245) + '-' + suffix;
}
