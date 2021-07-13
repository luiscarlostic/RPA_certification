*** Settings ***
Documentation    Orders robots from RobotSpareBin Industries Inc.
...               Saves the order HTML receipt as a PDF file.
...               Saves the screenshot of the ordered robot.
...               Embeds the screenshot of the robot to the PDF receipt.
...               Creates ZIP archive of the receipts and the images.

Library    RPA.Browser.Selenium
Library    RPA.Tables
Library    RPA.PDF
Library    RPA.HTTP
Library    RPA.FileSystem
Library    RPA.Archive
Library    RPA.Dialogs
Library    RPA.Robocloud.Secrets
Task Teardown    Close All Browsers

*** Variables ***
${head_dropdown}=    id:head
${order_element}=    id:order-completion
${TEMP_OUTPUT_DIRECTORY}=    ${OUTPUT_DIR}${/}tmp${/}
${ORDERS_TEMP_OUTPUT_DIRECTORY}=    ${OUTPUT_DIR}${/}orders${/}

*** Keywords ***
Get value of the vault
    ${secret}=    Get Secret    credentials
    [Return]    ${secret}[robot_url]

Open the robot order website
    ${url}=    Get value of the vault
    Open Available Browser    ${url}
    
Close the annoying modal
    Click Element When Visible    css=.btn.btn-dark

Get orders
    ${target_file}=    Set Variable    ${OUTPUT_DIR}${/}orders.csv
    Download        url=https://robotsparebinindustries.com/orders.csv    target_file=${target_file}    overwrite=${True}
    ${orders}=    Read table from CSV    ${target_file}
    [Return]    ${orders}
    
Fill the form
    [Arguments]    ${row}
    Wait Until Element Is Visible    ${head_dropdown}
    Select From List By Value    ${head_dropdown}    ${row}[Head]
    Click Element When Visible    id:id-body-${row}[Body]
    Input Text When Element Is Visible    css=input[type="number"]    ${row}[Legs]
    Input Text When Element Is Visible    id:address    ${row}[Address]

Preview the robot
    Click Element When Visible    id:preview
    Wait Until Element Is Visible    id:robot-preview-image

Submit the order
    Wait Until Keyword Succeeds    5x    1s    Click Submit

Click Submit
    Click Element When Visible    id:order
    Assert Order

Assert Order
    Page Should Not Contain Element    css=.alert.alert-danger
    Wait Until Page Contains Element    ${order_element}
    Wait Until Page Contains Element    id:robot-preview

Store the receipt as a PDF file
    [Arguments]    ${ORDER_NUMBER}
    ${order_html}=    Get Element Attribute    ${order_element}    outerHTML
    ${receipt_pdf_path}=    Set Variable    ${ORDERS_TEMP_OUTPUT_DIRECTORY}order${ORDER_NUMBER}.pdf
    HTML to PDF    ${order_html}    ${receipt_pdf_path}
    [Return]    ${receipt_pdf_path}

Take a screenshot of the robot
    [Arguments]    ${ORDER_NUMBER}
    ${robot_screenshot_path}=    Set Variable    ${TEMP_OUTPUT_DIRECTORY}robot${ORDER_NUMBER}.png
    Screenshot    locator=id:robot-preview-image    filename=${robot_screenshot_path}
    [Return]    ${robot_screenshot_path}

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Open Pdf    ${pdf}
    ${files}=    Create List
    ...    ${screenshot}:align=center
    Add Files To Pdf    ${files}    ${pdf}    append=${True}
    Close Pdf    ${pdf}

Go to order another robot
    Click Element     id:order-another

Create a ZIP file of the receipts
    [Arguments]    ${pdf_name}
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}${/}${pdf_name}.zip
    Archive Folder With Zip
    ...    ${ORDERS_TEMP_OUTPUT_DIRECTORY}
    ...    ${zip_file_name}
    Cleanup temporary PDF directory

Cleanup temporary PDF directory
    Remove Directory    ${ORDERS_TEMP_OUTPUT_DIRECTORY}    True
    Remove Directory    ${TEMP_OUTPUT_DIRECTORY}    True
    Success dialog

Input dialog
    Add heading    Input text
    Add text input    pdf_name    
    ...    label=Order's PDF name
    ...    placeholder=Enter PDF name here
    ${result}=    Run dialog
    [Return]    ${result.pdf_name}


Success dialog
    Add icon    Success
    Add heading    Your orders have been processed
    Add files    *.pdf
    Run dialog    title=Success

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
     Open the robot order website
     ${zip_name}=    Input dialog
     ${orders}=    Get orders
     FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Submit the order
        ${pdf}=    Store the receipt as a PDF file     ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
     END
     Create a ZIP file of the receipts    ${zip_name}