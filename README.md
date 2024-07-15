# Project Name: Education Cloud Payment Portal

## Description
This package aims to provide a comprehensive solution for managing course offerings and payments on Salesforce Education Cloud Experience sites. The integration with Stripe ensures secure payment processing, while the custom objects facilitate efficient order and transaction management.

## Deployment

### Pre-Steps
1. **Create a new Education Cloud trial org.**
https://developer.salesforce.com/free-trials/comparison/education-cloud
2. **Enable required settings:**
    - Go to **Digital Experience** -> **Settings**.
    - Enable **ExperienceBundle Metadata API in Digital Experiences**.
    - Allow using standard external profiles for self-registration user creation and check-in.

### Clone the Repository and Authorize the Org
1. **Clone the repository:**
    ```sh
    git clone https://github.com/KankshitAdhaulia/Education-Cloud-Payment-Portal.git
    ```
2. **Navigate to the project directory:**
    ```sh
    cd your-repository
    ```
3. **Update site metadata:**
    - In the repository, go to `sites -> Education_Payment_Portal.site-meta.xml`.
    - Change the `<siteAdmin>` and `<siteGuestRecordDefaultOwner>` to any Admin User of your new org.
    - Set Default External Access of Learning Access to Public Read.
4. **Authorize your org:**
    ```sh
    sfdx auth:web:login -a YourOrgAlias
    ```
5. **Push source to the org:**
    ```sh
    sf project deploy start
    ```

### Post-Steps
1. **Update Success and Cancel URLs in StripeService.apex.**
2. **In the External Credential named 'Stripe_EC', create a new Authentication Parameter in Principals with the following values:**
    - Name: `Authorization`
    - Value: your Stripe Key

    Steps to get the Stripe key:
    1. Log in to your Stripe Account.
    2. Go to Developers.
    3. Click on API keys.
    4. Click on Reveal Test Key and copy it.

3. **Create a Contact and a new associated Account record and enable Customer User:**
    - Provide Email, Username, profile as Customer Community Plus, and click Save.
    - Assign permission sets to the Experience User:
        - **Applicant Permission Set for Experience User**
        - **Education Cloud for Experience Cloud Access - Clone**
4. **Assign the Education Cloud Site Admin Permission Set to an Admin User.**
5. **Go to Digital Experiences -> All Sites -> Click on Builder for the site 'Education Payment Portal'. Update the Navigation Bar to include Learning Courses and publish the site.**
6. Go to the contact record you created and click on 'Login To Experience as User'.
7. Go to Learning Courses.
8. Go to Related and select a Course Offering.
9. Add the Course Offering to Cart.
10. Click on Checkout.

## Author
- **Author:** Kankshit Adhaulia
- **Email:** ad.kankshit@concret.io
