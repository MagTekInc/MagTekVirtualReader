> The **MagTek Virtual Reader iOS** App enables Tap to Pay on iPhone using the **Magensa Payment Protection Gateway (MPPG)**. Use this guide to install the app and run test transactions.

<img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image4.png" style="width:3.83353in;height:6.08365in" />

> **Figure 1.** Tap to Pay on iPhone using **MagTek** **Virtual** **Reader** **iOS App** present a contactless card or mobile device near the iPhone to initiate a secure transaction.

# Table of contents

- [MagTekVirtualReader iOS App — User Guide](#magtekvirtualreader-ios-app--user-guide)

  - [Table of contents](#table-of-contents)

  <!-- -->

  - [Overview](#overview)

  - [Requirements](#requirements)

  - [Install & Open the App](#build-install-open-the-app)

  - [Configuration](#configuration)

  - [Run a Test Transaction](#run-a-test-transaction)

  - [Result States](#result-states)

  - [View Log](#view-log)

  - [Privacy & Security Notes](#privacy-security-notes)

  <!-- -->

  - [Terms and Conditions](#terms-and-conditions)

  - [License](#license)

  - [Appendix A — Glossary](#appendix-a-glossary)

  - [Build](#build)

# Overview

> This app is intended for **developers, testers, and pilot merchants**. It connects to Magensa (MPPG), verifies Tap to Pay on iPhone capability on the device, and processes contactless payments on supported iPhones.

# Requirements

- **Device:** iPhone that supports **Tap to Pay on iPhone** (physical device required; simulator not supported)

- **iOS:** 17.4 or later

- **Account:** MPPG credentials (MPPG username, MPPG password and MPPG CustomerCode). An MPPG v5 Unigate pilot account is required. If you don’t have a pilot account, please contact your MagTek Sales Professional to have one created.

- **Network:** Internet access (Wi-Fi or cellular)

# Build, Install & Open the App

> ⚠ **Important Release Note**

- The app is **not available on the Apple App Store**.

- The information for accessing the source will be provided on **MagTek.com**.

- At this time, there is **no public download link.**.


To use the app developers obtain the source code and build it with **Xcode.** The Build part number (PN) is **1000009873**.

> <img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image5.png" style="width:2.25in;height:2.29167in" />
>
> **Figure 2.** iOS **Virtual Reader** app icon.

# Configuration

> Open the app and expand **CONFIGURATION**. The only item available is **View Log**, all other fields are preconfigured:

1.  **Fetch JWT Token** – obtains a session token for Magensa. Below is an example of the following decoded JWT Token:  
    eyJhbGciOiJFUzI1NiIsImtpZCI6IjAzYmJmOTUwLTBkYmUtNGEwMS1hYWNmLTY5NTIzYzFiZjJlNSIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJwcm9kdWN0aW9uLXBvcy12MSIsImF2cyI6WyI2MDQ5MmEzODc2NGYxMWYyMjdlNDc3YzgwMDdmNjU3NDM2MjYxYzA1YWFmMTQyZTk5ZGYzYzQ2M2Y3MGMzODZkIl0sImV4cCI6MTc1NzA4NzIyNiwiaWF0IjoxNzU2OTE0NDI2LCJpc3MiOiJNYWdUZWsiLCJqdGkiOiI1OWFlODY1MS1kNGU3LTQ0YTItOWYxYi05OWU4MTQ2YTg4MjYiLCJtYWEiOlsiUFJFUEFSRSIsIkxJTksiXSwibWlkIjoic2kxMzE4NDIwNi5tcHBndHN5c2xpdmUiLCJtYm4iOiJNYWdlbnNhIFRlc3QiLCJtY2MiOjUzOTksIm5iZiI6MTc1NjkxNDQyNiwidHBpZCI6IjQwODQwMDAwLTAwMDAtMDAwMC0wYmM5LWJjNTI2OGFmM2M2ZiJ9.zH1p35N9mlpBMNDcqXRAq1DuTFFDoFw1YGyiNROt5IUTZ8jUvQcKw6T0NMlnVFmtUi17M_IeCfpzAO9vMZWY5A  
    <img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image6.png" style="width:2.84737in;height:3.41684in" />

2.  **Link Merchant Account** – associates the device/session with the test merchant.

3.  **Is Account Linked?** – verifies link status.

4.  **Prepare Reader Session** – sets up Tap to Pay session on the device.

5.  **Release Reader & Session** – cleanly tears down the session when finished.

6.  **View Log** – shows verbose event logs (useful in testing).

> <img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image7.png" style="width:3.63542in;height:7.09375in" />
>
> **Figure 3. CONFIGURATION** panel with setup actions. These fields come preconfigured.

# Run a Test Transaction

1.  Ensure the status reads **Tap to Pay Ready**.

2.  In **Transaction**, select **SALE** (default).

3.  Enter the **Amount** (e.g., 2.00).

4.  Press **Pay**.

5.  Present a contactless card/phone/watch near the top of the iPhone and follow on-screen prompts.

<img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image8.png" style="width:3.47917in;height:7.09375in" />

**Figure 4.** Enter an amount, confirm **Processor** and **Transaction** type, then press **Pay** to activate Tap to Pay on iPhone.

# Result States

> When the transaction completes, the app displays an **APPROVED** or **DECLINED** dialog with summary details.

<img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image9.png" style="width:3.48958in;height:7.09375in" />

> **Figure 5. APPROVED** result showing Requested Amount and Approved Amount. Tap **OK** to return to the main screen.
>
> <img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image10.png" style="width:3.53125in;height:7.09375in" />
>
> **Figure 6. DECLINED** result with requested/authorized amounts and a transactionId (Trans \#) for support. Status messages reported by the iOS device are passed back and noted with Apple in parenthesis, “(Apple)”.

# View Log

> Use **View Log** under **CONFIGURATION** to see detailed events from the MagTek Virtual Reader SDK including messages received from Magensa services.

- Helpful for QA and support.

- Avoid sharing logs that include sensitive IDs outside your test org.

<img src="./MagTek-Virtual-Reader-iOS-SDK_media/media/image11.jpeg" style="width:3in;height:6.51042in" />

> **Figure 6.** Example **View Log** output showing SDK version, iOS version, reader ID, and token fetch events.

# Privacy & Security Notes

- Treat device screenshots and logs as **confidential** if they contain transaction IDs or merchant info.

- Follow your organization’s security policies for handling payment data and artifacts.

# 

# 

# 

# Terms and Conditions

> [Terms and Conditions](https://www.magtek.com/about/policy?tab=terms)<span id="license" class="anchor"></span>
>
> [License](https://www.magtek.com/about/policy?tab=software)

# Appendix A — Glossary

- **Tap to Pay on iPhone**: Apple feature enabling contactless acceptance without extra hardware on supported iPhones.

- **Magensa (MPPG)**: Magensa Payment Protection Gateway for tokenization, routing, and processing.

- **JWT**: JSON Web Token used to authenticate the app with backend services.

- **Processor**: The host endpoint/profile used for transaction routing (e.g., **TSYS – Pilot**, **Rapid Connect v3**).

- **Tap to Pay Ready**: App state indicating the Tap to Pay session is initialized and ready to accept a tap.

# Build

> PN1000009873
