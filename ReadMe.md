# Import and setup of Monitoring Apps for Qlik Sense Enterprise on Windows

This project contains generic Powershell scripts which utilize Qlik Sense Repository Service (QRS) API to help to expedite the configuration of the Qlik Sense Monitoring Apps. 

## Get-Help

Powershell `get-help` command can be used to get help details on each script example in this repository. The same help content can also be found inside each PS1 file in the `<# #>` comment section at the top of each file.

Run `get-help <PS1_file_path> -detailed` to get details on the PS1 file purpose and how it could be used. 
```
get-help .\<filename>.ps1 -Detailed
get-help .\myscript.ps1 -Detailed
```

## References 

* (Qlik Sense for Administrators: Monitoring a Qlik Sense Enterprise on Windows site)[https://help.qlik.com/en-US/sense-admin/June2020/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Administer_QSEoW/Monitoring_QSEoW/Monitor-Qlik-Sense-site.htm]
* (Qlik Sense for Developers: Upload App )[https://help.qlik.com/en-US/sense-developer/June2020/Subsystems/RepositoryServiceAPI/Content/Sense_RepositoryServiceAPI/RepositoryServiceAPI-App-Upload-App.htm]
* (QRS API: POST /app/upload)[https://help.qlik.com/en-US/sense-developer/APIs/RepositoryServiceAPI/index.html?page=318]

## License

This project is provided "AS IS", without any warranty, under the MIT License - see the [LICENSE](LICENSE) file for details
