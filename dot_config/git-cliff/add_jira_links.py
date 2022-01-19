"""Update Changelog with links to JIRA tickets.

```sh
# Could use cookies and httpstat to retrieve the JIRA ticket title

BASE_URL=https://jira.net/browse
TICKET=PPLMS-865
COOKIES=...

httpstat '$BASE_URL/$TICKET' -H 'Cookie: $COOKIES' --insecure
```

```python
# Or entirely in Python

import requests
from bs4 import BeautifulSoup

RAW_COOKIES = '...'
COOKIES = {
    cookie.split('=')[0].strip(): cookie.split('=')[1].strip()
    for cookie in RAW_COOKIES.split(';')
}  # Convert to dictionary for requests

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

BASE_URL = "https://jira.net/browse"
JIRA_TAG_RE = re.compile(r"\[(\w+[- ]\d+)\]")


def _br(content: str) -> str:
    return f"[{content}]"


# PLANNED: Execute git-cliff to generate the initial changelog file here
cl = Path("CHANGELOG.md").absolute()

# Replace the file contents with links to each JIRA ticket
content = ""
for line in cl.read_text().split("\n"):
    for match in JIRA_TAG_RE.findall(line):
        ticket_id = match.replace(" ", "-")
        ticket_url = f"{BASE_URL}/{ticket_id}"
        # PLANNED: Could retrieve the JIRA title, but too much effort. See notes above
        line = line.replace(
            _br(match),
            _br(_br(ticket_id)) + f"({ticket_url})",
        )
    content += line + "\n"
cl.write_text(content)
