CREATE LOGIN rodauth_test WITH PASSWORD = 'rodauth_test';
CREATE LOGIN rodauth_test_password WITH PASSWORD = 'rodauth_test';
CREATE DATABASE rodauth_test;
GO
USE rodauth_test;
GO
CREATE USER rodauth_test FOR LOGIN rodauth_test;
GRANT CONNECT, EXECUTE TO rodauth_test;
EXECUTE sp_changedbowner 'rodauth_test_password';
GO
exit
