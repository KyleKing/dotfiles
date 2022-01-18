"""Update Changelog for Reviewer.
```sh
# With cookies and httpstat, retrieve JIRA ticket title

BASE_URL=https://issues.roaminsight.net/browse
TICKET=PPLMS-865
COOKIES=AJS.conglomerate.cookie="|hipchat.inapp.links.first.clicked.kyleking=false"; _DUO_APER_LOCAL_=801cf1ce1e864120f89e7d12fee0d4b7175d8482082977e95e32b509a6360635; atlassian.xsrf.token=BGP9-7IK0-VLIU-Q4FA_b3896939b292f88fd83ca1c66aa4da15799cd932_lin; JSESSIONID=22383DDCDDA07D9520098332C347904B; jira.editor.user.mode=wysiwyg; DWRSESSIONID=0QsAuvxp3j69djM8GrI*lWWBvLn

httpstat '$BASE_URL/$TICKET' -H 'Cookie: $COOKIES' --insecure

httpstat 'https://issues.roaminsight.net/browse/PPLMS-865' -H 'Cookie: AJS.conglomerate.cookie="|hipchat.inapp.links.first.clicked.kyleking=false"; _DUO_APER_LOCAL_=801cf1ce1e864120f89e7d12fee0d4b7175d8482082977e95e32b509a6360635; atlassian.xsrf.token=BGP9-7IK0-VLIU-Q4FA_b3896939b292f88fd83ca1c66aa4da15799cd932_lin; JSESSIONID=22383DDCDDA07D9520098332C347904B; jira.editor.user.mode=wysiwyg; DWRSESSIONID=0QsAuvxp3j69djM8GrI*lWWBvLn' --insecure
```

```python
import requests
from bs4 import BeautifulSoup
RAW_COOKIES = '_DUO_APER_LOCAL_=31a1ebcbb9cb62b4f170244faef9f17482a38524acd128effa0c9bbad1294ec5; atlassian.xsrf.token=BGP9-7IK0-VLIU-Q4FA_47ddc71312e62c551632f7dbe9bd8094c81ef521_lin; JSESSIONID=E4D136EC7AA6EA14930EA5C87FB005CE; jira.editor.user.mode=wysiwyg; DWRSESSIONID=0QsAuvxp3j69djM8GrI*lWWBvLn; AJS.conglomerate.cookie="|hipchat.inapp.links.first.clicked.kyleking=false"'
COOKIES = {
    cookie.split('=')[0].strip(): cookie.split('=')[1].strip()
    for cookie in RAW_COOKIES.split(';')
}
# Parse the JIRA Ticket Title
breakpoint()
resp = requests.get(ticket_url, cookies=COOKIES)
resp.raise_for_status()
soup = BeautifulSoup(resp.text)
print(soup.prettify())
breakpoint()
```

"""

import re
from pathlib import Path

BASE_URL = "https://issues.roaminsight.net/browse"
JIRA_TAG_RE = re.compile(r"\[(\w+[- ]\d+)\]")


def _br(content: str) -> str:
    return f"[{content}]"


# PLANNED: Execute git-cliff
cl = Path("/Users/kyleking/Developer/Core/reviewer-core/CHANGELOG.md")
content = ""
for line in cl.read_text().split("\n"):
    for match in JIRA_TAG_RE.findall(line):
        ticket_id = match.replace(" ", "-")
        ticket_url = f"{BASE_URL}/{ticket_id}"
        # PLANNED: Could retrieve the JIRA ticket title, but too much effort
        line = line.replace(
            _br(match),
            _br(_br(ticket_id)) + f"({ticket_url})",
        )
    content += line + "\n"

# HACK: Write to same file...
(cl.parent / "CL.md").write_text(content)
