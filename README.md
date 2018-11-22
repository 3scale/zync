# Zync - the sync tool

Zync is going to take your 3scale data and pushes it somewhere else, reliably. Offers only one directional sync (from 3scale to other systems).

## Terminology

Before describing the design it is important to define the terms.

* **Zync** - deployment of this project, Web API.


* **3scale** - 3scale API Manager (system).
* **Tenant** - mapping of Provider id registered in 3scale API Manager to domain and access token.
* **Model** - relevant object in **3scale** like Application, Limit, Metric, Service.
* **Notification** - Message sent to **Zync** describing the **model** that changed and having all required properties to fetch it from the API later.
  * Example: Application 3456, tenant_id: 26
  * Example: Limit 4566, metric_id: 36, application_id: 46, tenant_id: 16
* **Update** - **Zync** fetches updated **Model** from the **Notifier** via the API using the information provided by the **Notification**.
* **Lock** - mechanism that preventing concurrent data access to the same scope.
  * Example: **Tenant Lock** would mean only one can be running for one **Tenant**.
  * Example: **Model** **Lock** - only one per uniquely identified **Model**.
* **Entry** - The information from the API provided by the **Update**.
* **Log** - ordered list of **Entries** as they were received.
* **Push** - a call from **Zync** to external service updating **model** data
* **Integration** - code that **pushes** **Log** **entries** one-by-one for the same **Model** to some external service.
  * Integration can access the **entries** **log** to fetch more data and for example handle **model** dependencies by accessing all dependent **models** and delete them before deleting the parent.
  * Integration keeps **Status** of each **model** synchronization state. If a **push** fails **status** should be updated to reflect that and keep trying.
* **Integration Configuration** - configuration for each instance of **Integration** for each **Tenant**. It is populated the same way as **Model** - by **Notification** and **Fetch**.

## Design

**Zync** is meant to synchronize data from **3scale** to external systems (like IDPs). Some people use Web-hooks  for this but without further logic they can be unreliable and arrive out of order. This tool is meant to synchronize the final state to a different systems.

The flow is defined as **3scale** -> **Zync** ( <- **3scale**) -> **Integration**. So **3scale** notifies **Zync** there was a change to a **model** but does not say more than primary key and information required to fetch it from the **3scale** API. In some cases **model** needs just its primary key (**id**) and in some it needs other metadata (usually primary keys of its parents) to compose the API call (service_id, metric_id, …).

**Zync** upon receiving the notification will acquire an **update model lock** and try to perform an **update**. Any information received this way is added as an **entry** to the **log** and the **model lock** is released. That **entry** can be either new data or information that the record is no longer there (404 from the API). If new **notification** came when the **model lock** was acquired, it is going to be processed after the lock is released.

After adding **entry** to the **log** an **integration** is triggered and acquires an **integration model lock** so it will process only one (latest) **entry** for a **model** at a time. After the **integration** finishes (with both failure or success) it will release the lock and trigger another run if failed.

## Properties

Given the locking on the **model** there will be some parallelisation, but also updates to one object will be serialized. This needs to be done to limit the network issues and ensure the request was delivered before issuing new one. 

Because **Zync** will keep a **log** of **events** it will be able to replay changes and recover last state just taking last revisions of each **model** and even remove the ones that have been created before but have been deleted.

## Data Model

**Record** types are for enforcing correctness of data on the database level and referential integrity. There is one relationship (Model -> Record) that can't have foreign constraint but can be recreated from other data.

### Tenant

| id (pk) | domain | access_token |
| ------- | ------ | ------------ |
| bigint  | string | string       |

### Notification

| id (pk) | model_class | model_id (fk) | data | tenant_id (fk) |
| ------- | ----------- | ------------- | ---- | -------------- |
| uuid    | string      | bigint        | json | bigint         |

### Application (Record)

| id (pk) | account_id | tenant_id (fk) |
| ------- | ---------- | -------------- |
| string  | bigint     | bigint         |

### Service (Record)

| id (pk) | tenant_id (fk) |
| ------- | -------------- |
| string  | bigint         |

### Metric (Record)

| id (pk) | service_id (fk) | tenant_id (fk) |
| ------- | --------------- | -------------- |
| string  | bigint          | bigint         |

### UsageLimit (Record)

| id (pk) | metric_id (fk) | plan_id | tenant_id (fk) |
| ------- | -------------- | ------- | -------------- |
| string  | bigint         | bigint  | bigint         |

### Model

| id (pk) | record_id (fk) | tenant_id (fk) |
| ------- | -------------- | -------------- |
| uuid    | bigint         | bigint         |

### Update 

| id (pk) | model_id (fk) | tenant_id (fk) |
| ------- | ------------- | -------------- |
| uuid    | uuid          | bigint         |

### Entry

| id (pk) | update_id (fk) | data | tenant_id (fk) |
| ------- | -------------- | ---- | -------------- |
| uuid    | uuid           | json | bigint         |

### Status

| id (pk) | integration_id (fk) | model_id (fk) | tenant_id (fk) |
| ------- | ------------------- | ------------- | -------------- |
| uuid    | uuid                | uuid          | bigint         |

