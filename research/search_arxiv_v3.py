#!/usr/bin/env python3
"""Direct arXiv search with broader queries, long delays."""
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import time
import json

ARXIV_NS = {
    'atom': 'http://www.w3.org/2005/Atom',
    'arxiv': 'http://arxiv.org/schemas/atom',
}

# Use more targeted search queries with arXiv search syntax
queries = [
    'ti:photovoltaic AND ti:self-consumption',
    'ti:solar AND ti:battery AND ti:dispatch',
    'ti:photovoltaic AND ti:inverter AND ti:clipping',
    'ti:PV AND ti:sizing AND ti:residential',
    'ti:solar AND ti:irradiance AND ti:estimation',
    'ti:photovoltaic AND ti:simulation AND ti:algorithm',
    'ti:battery AND ti:storage AND ti:solar AND ti:optimization',
    'ti:microinverter AND ti:photovoltaic',
]

all_papers = {}
seen_ids = set()

for i, query in enumerate(queries):
    print(f"Query {i+1}/{len(queries)}: {query}")
    params = urllib.parse.urlencode({
        'search_query': query,
        'start': 0,
        'max_results': 10,
        'sortBy': 'relevance',
        'sortOrder': 'descending'
    })
    url = f'http://export.arxiv.org/api/query?{params}'
    retries = 0
    success = False
    while retries < 3 and not success:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (research)'})
            with urllib.request.urlopen(req, timeout=45) as resp:
                data = resp.read().decode('utf-8')
            root = ET.fromstring(data)
            entries = root.findall('atom:entry', ARXIV_NS)
            print(f"  Got {len(entries)} results")
            for entry in entries:
                arxiv_id_el = entry.find('atom:id', ARXIV_NS)
                if arxiv_id_el is None:
                    continue
                arxiv_id = arxiv_id_el.text.strip()
                if arxiv_id in seen_ids:
                    continue
                seen_ids.add(arxiv_id)
                title_el = entry.find('atom:title', ARXIV_NS)
                title = title_el.text.strip().replace('\n', ' ') if title_el is not None else 'N/A'
                summary_el = entry.find('atom:summary', ARXIV_NS)
                summary = summary_el.text.strip().replace('\n', ' ') if summary_el is not None else 'N/A'
                published_el = entry.find('atom:published', ARXIV_NS)
                published = published_el.text.strip()[:10] if published_el is not None else 'N/A'
                authors = [a.find('atom:name', ARXIV_NS).text for a in entry.findall('atom:author', ARXIV_NS)]
                pdf_url = None
                for link in entry.findall('atom:link', ARXIV_NS):
                    if link.get('title') == 'pdf':
                        pdf_url = link.get('href')
                        break
                if not pdf_url:
                    pdf_url = arxiv_id.replace('/abs/', '/pdf/') + '.pdf'
                
                paper = {
                    'title': title,
                    'authors': authors[:5],
                    'published': published,
                    'arxiv_id': arxiv_id,
                    'pdf_url': pdf_url,
                    'abstract': summary[:2000],
                    'query_found': query,
                }
                all_papers[arxiv_id] = paper
            success = True
        except Exception as e:
            retries += 1
            print(f"  Attempt {retries} error: {e}")
            time.sleep(30)
    
    if i < len(queries) - 1:
        wait = 25
        print(f"  Sleeping {wait}s...")
        time.sleep(wait)

print(f"\nTotal unique papers: {len(all_papers)}")
with open('/home/paperclip/git/pv-calculator/research/arxiv_v3_raw.json', 'w') as f:
    json.dump(list(all_papers.values()), f, indent=2)
print("Saved.")
