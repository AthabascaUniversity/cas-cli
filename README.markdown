# Usage

```
git clone git@git.athabascau.ca:au-cas/cas-cli.git;
cd cas-cli
./cas-cli.pl 29302 https://cas.yourdomain.com/cas
```

# Dependencies

On Redhat systems you should be able to use it by installing these...

    sudo yum install -y perl-URI-Encode perl-XML-Tidy perl-HTTP-Server-Simple perl-DateTime
    
On Debian systems you should be able to use it by installing these...

    sudo apt install libencode-detect-perl libxml-tidy-perl libtest-http-server-simple-perl libdatetime-perl
    
# Benefits
This application is stateless and does not even store your authenticated state.  This is quite beneficial when you are setting up a new CAS version and are changing configurations over and over again to play with settings to find out how they work.  You just keep on clicking the `SAML Auth` or `CAS Auth` links repetitively as you adjust your CAS configs.  If you were to point one of your applications to CAS to do this repetitive testing, you'd have to login, logout, login, logout, repeat forever!

# License
```Copyright [2018] [Athabasca University IT]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```