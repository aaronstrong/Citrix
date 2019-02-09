﻿## Load the Citrix snap-ins
Disable configuration logging for the XD site:

$ServerName = "CTX_76_DB"
Set-AdminDBConnection -DBConnection $csSite
Test-AdminDBConnection -DBConnection $csSite
Test-AnalyticsDBConnection -DBConnection $csSite # 7.6 and newer
Test-AppLibDBConnection -DBConnection $csSite # 7.8 and newer
Test-BrokerDBConnection -DBConnection $csSite
Test-ConfigDBConnection -DBConnection $csSite
Test-EnvTestDBConnection -DBConnection $csSite
Test-HypDBConnection -DBConnection $csSite
Test-LogDBConnection -DBConnection $csSite
Test-LogDBConnection -DataStore Logging -DBConnection $csLogging
Test-MonitorDBConnection -DBConnection $csSite
Test-MonitorDBConnection -Datastore Monitor -DBConnection $csMonitoring
Test-OrchDBConnection -DBConnection $csSite # 7.11 and newer
Test-ProvDBConnection -DBConnection $csSite
Test-SfDBConnection -DBConnection $csSite
Test-TrustDBConnection -DBConnection $csSite # 7.11 and newer