# Reservation Search Flow – Build Guide (Option 1: Single Screen + Loop Back)

Build this **Screen Flow** in Flow Builder so one screen has 6 search inputs, a Search button, a Data Table for results, and a New Search button. After Search, the flow runs Get Records and returns to the same screen to show results.

---

## 1. Create the Flow

1. Setup → **Flows** → **New Flow** → **Screen Flow** → Create.
2. Name: **Reservation Search**.
3. API Name: **Reservation_Search** (or leave default).

---

## 2. Create Variables

Create these **Resource** variables (Type = **Variable**):

| API Name            | Data Type | Default Value | Description        |
|---------------------|-----------|---------------|--------------------|
| `varConfirmationNumber` | Text    | (none)        | Confirmation Number |
| `varEmail`              | Text    | (none)        | Email               |
| `varCheckInDate`        | Date    | (none)        | Check-In Date       |
| `varHotelName`          | Text    | (none)        | Hotel               |
| `varFirstName`          | Text    | (none)        | First Name          |
| `varLastName`           | Text    | (none)        | Last Name           |
| `varReservations`       | **Record** (Reservations__c), **Allow multiple values (collection)** | (none) | Search results |

To add each variable: **New Resource** → **Variable** → set **API Name**, **Data Type**, and for `varReservations` set **Object** = Reservations__c and check **Allow multiple values (collection)**.

---

## 3. Create the Screen – “Reservation Search”

Add a **Screen** element. Name: **Reservation_Search_Screen**.

### 3.1 Search inputs (store in variables)

Add 6 **Display Text** or **Input** components and **assign** their value to the variables (use “Store in variable” or “Output” so the value is saved into the variable).

| Label           | Field API (for reference) | Component type | Store output in      |
|----------------|----------------------------|----------------|-----------------------|
| Confirmation Number | confirmationNumber__c  | Input (Text)   | varConfirmationNumber |
| Email                | EmailAddress__c         | Input (Text)   | varEmail              |
| Check-In Date        | checkInDate__c          | Input (Date)   | varCheckInDate        |
| Hotel                | hotelName__c            | Input (Text)   | varHotelName          |
| First Name           | frst_nm__c              | Input (Text)   | varFirstName          |
| Last Name            | lst_nm__c               | Input (Text)   | varLastName           |

For each: add the component, set the **Label**, then in the component properties set **Store in variable** (or **Output**) to the corresponding variable above.

### 3.2 Data Table (results)

- Add **Data Table**.
- **Resource**: `varReservations` (the collection variable).
- **Columns**: add columns for the fields you want to show (e.g. Confirmation Number, Email, Check-In Date, Hotel, First Name, Last Name, and any others). Map each column to the correct Reservations__c field.

The table will be empty on first load and show results after the user clicks Search.

### 3.3 Buttons (two outcomes)

- Add **two buttons** on the screen:
  - **Search** (primary) → this path will run Get Records and then go back to this screen.
  - **New Search** → this path will clear the collection (and optionally the inputs) and go back to this screen.

Configure each button’s **Navigation** (or “Go to”) in the next steps.

---

## 4. Get Records (Reservations__c)

Add a **Get Records** element. Name: **Get_Reservations**.

- **Object**: Reservations__c.
- **Filter** (Conditions):
  - **confirmationNumber__c** → **Contains** → `varConfirmationNumber`
  - **EmailAddress__c** → **Contains** → `varEmail`
  - **checkInDate__c** → **Equals** → `varCheckInDate`
  - **hotelName__c** → **Contains** → `varHotelName`
  - **frst_nm__c** → **Contains** → `varFirstName`
  - **lst_nm__c** → **Contains** → `varLastName`
- Filter logic: **All conditions are met (AND)**.
- **Store in**: `varReservations` (the collection variable you created). Get Records will overwrite it with the query results.

Optional: if you want to only apply a filter when the user entered something, you’ll need separate logic (e.g. Decision + multiple Get Records or an Apex invocable with dynamic SOQL). For a first version, the above is fine; leaving a field blank may match records where that field is empty.

---

## 5. Assign Get Records result to the collection

(Get Records stores directly into `varReservations`; no separate Assignment needed.)

Add an **Assignment** element. Name: **Clear_Results** (see next section). Skip the Assign_Results step.

- **Variable**: `varReservations`
- **Operator**: Equals (or “Set”)
- **Value**: the output of Get Records (e.g. `Get_Reservations` → record collection).

So: **varReservations** = **Get_Reservations** (the collection returned by Get Records).

---

## 6. Clear results (for “New Search”)

Add another **Assignment** element. Name: **Clear_Results**.

- **Variable**: `varReservations`
- **Operator**: Equals
- **Value**: leave empty or set to a new, empty collection of Reservations__c.

(To clear the 6 input variables so the text/date fields are blank when they come back to the screen, add more rows in this Assignment: set each of the 6 variables to blank/default.)

---

## 6. Connect the paths

- **Start** → **Reservation_Search_Screen** (first time user sees the screen).
- From **Reservation_Search_Screen**:
  - When user clicks **Search** → connect to **Get_Reservations**.
  - When user clicks **New Search** → connect to **Clear_Results**.
- **Get_Reservations** → **Reservation_Search_Screen** (go back to the same screen; table now shows `varReservations`).
- **Clear_Results** → **Reservation_Search_Screen** (go back to the same screen with cleared results).

So both paths (Search and New Search) end by going back to the same screen.

---

## 7. Button configuration on the screen

On **Reservation_Search_Screen**:

- **Search** button: set **Navigate** (or “Go to”) to **Get_Reservations**.
- **New Search** button: set **Navigate** to **Clear_Results**.

Exact labels in the UI may be “Next”, “Go to”, or “Navigate to element” depending on your Flow Builder version.

---

## 8. Optional: validation (at least one search field)

Before Get Records, you can add a **Decision** that checks whether at least one of the 6 variables is not blank. If all are blank, show a **Screen** or **Display Text** saying “Enter at least one search value”, then go back to **Reservation_Search_Screen**. If at least one has value, go to **Get_Reservations**.

---

## 9. Save and activate

- **Save** the flow.
- **Activate** when ready.
- Run it from a **Tab**, **App**, **Lightning page**, or **Experience Cloud** by adding the Flow screen flow component and selecting **Reservation Search**.

---

## Object and fields reference

| Purpose           | API name              | Type  |
|------------------|------------------------|-------|
| Object           | Reservations__c        | Custom Object |
| Confirmation #   | confirmationNumber__c  | Text  |
| Email            | EmailAddress__c        | Text  |
| Check-In         | checkInDate__c         | Date  |
| Hotel            | hotelName__c           | Text  |
| First Name       | frst_nm__c             | Text  |
| Last Name        | lst_nm__c              | Text  |

---

## Summary flow shape

```
Start → [Screen: 6 inputs + Data Table (varReservations) + Search | New Search]
           │
           ├─ Search    → Get Records (Reservations__c) → store in varReservations → back to Screen
           └─ New Search → Assign clear varReservations → back to Screen
```

After “Search”, the same screen is shown again with the Data Table bound to `varReservations`, so results appear on the same screen.
