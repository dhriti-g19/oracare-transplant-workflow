-- USER TABLE
CREATE TABLE User_ (
    User_ID           NUMBER PRIMARY KEY,
    Name              VARCHAR2(50) NOT NULL,
    Date_of_Birth     DATE NOT NULL,
    Gender            VARCHAR2(10),
    Blood_Group       VARCHAR2(5),
    Medical_insurance NUMBER(1),
    Medical_history   VARCHAR2(200),
    Street            VARCHAR2(50),
    City              VARCHAR2(30),
    State             VARCHAR2(30)
);

-- ORGANIZATION
CREATE TABLE Organization (
    Organization_ID   NUMBER PRIMARY KEY,
    Organization_name VARCHAR2(50),
    Location          VARCHAR2(50),
    Government_approved NUMBER(1),
    Password          VARCHAR2(100)
);

-- DOCTOR
CREATE TABLE Doctor (
    Doctor_ID       NUMBER PRIMARY KEY,
    Doctor_Name     VARCHAR2(50),
    Specialization  VARCHAR2(50),
    Organization_ID NUMBER,
    Password          VARCHAR2(100),
    FOREIGN KEY (Organization_ID)
        REFERENCES Organization(Organization_ID)
);

-- PATIENT
CREATE TABLE Patient (
    Patient_ID            NUMBER PRIMARY KEY,
    User_ID               NUMBER,
    Doctor_ID             NUMBER,
    Reason_of_procurement VARCHAR2(100),
    FOREIGN KEY (User_ID)
        REFERENCES User_(User_ID),
    FOREIGN KEY (Doctor_ID)
        REFERENCES Doctor(Doctor_ID)
);

-- DONOR
CREATE TABLE Donor (
    Donor_ID           NUMBER PRIMARY KEY,
    User_ID            NUMBER,
    Organization_ID    NUMBER,
    Reason_of_donation VARCHAR2(100),
    FOREIGN KEY (User_ID)
        REFERENCES User_(User_ID),
    FOREIGN KEY (Organization_ID)
        REFERENCES Organization(Organization_ID)
);

-- ORGAN MASTER
CREATE TABLE Organ (
    Organ_ID   NUMBER PRIMARY KEY,
    Organ_name VARCHAR2(20)
);

-- DONATION
CREATE TABLE Donation (
    Donation_ID   NUMBER PRIMARY KEY,
    Donor_ID      NUMBER,
    Organ_ID      NUMBER,
    Donation_date DATE,
    Status        VARCHAR2(20),
    FOREIGN KEY (Donor_ID)
        REFERENCES Donor(Donor_ID),
    FOREIGN KEY (Organ_ID)
        REFERENCES Organ(Organ_ID)
);

-- REQUEST
CREATE TABLE Request (
    Request_ID    NUMBER PRIMARY KEY,
    Patient_ID    NUMBER,
    Organ_ID      NUMBER,
    Request_date  DATE,
    Urgency_level VARCHAR2(20),
    FOREIGN KEY (Patient_ID)
        REFERENCES Patient(Patient_ID),
    FOREIGN KEY (Organ_ID)
        REFERENCES Organ(Organ_ID)
);

CREATE TABLE Transaction_ (
    Transaction_ID      NUMBER PRIMARY KEY,
    Patient_ID          NUMBER,
    Donor_ID            NUMBER,
    Organ_ID            NUMBER,
    Date_of_transaction DATE,
    Status              VARCHAR2(20),
    FOREIGN KEY (Patient_ID)
        REFERENCES Patient(Patient_ID),
    FOREIGN KEY (Donor_ID)
        REFERENCES Donor(Donor_ID),
    FOREIGN KEY (Organ_ID)
        REFERENCES Organ(Organ_ID)
);

CREATE TABLE log_ (
    querytime TIMESTAMP DEFAULT SYSTIMESTAMP,
    comment_  VARCHAR2(500)
);

COMMIT;