#!/usr/bin/env python3
"""Search arXiv API for PV/solar calculator related papers - with rate limiting."""
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import time
import json

ARXIV_NS = {
    'atom': 'http://www.w3.org/2005/Atom',
    'arxiv': 'http://arxiv.org/schemas/atom',
    'opensearch': 'http://a9.com/-/spec/opensearch/1.1/'
}

queries = [
    'photovoltaic simulation self-consumption',
    'solar PV battery dispatch optimization residential',
    'PV system sizing calculator algorithm',
    'solar irradiance estimation residential rooftop',
    'inverter clipping photovoltaic',
    'battery storage state of charge management PV',
]

all_papers = {}
seen_ids = set()

for i, query in enumerate(queries):
    print(f"Query {i+1}/{len(queries)}: {query}")
    params = urllib.parse.urlencode({
        'search_query': f'all:{query}',
        'start': 0,
        'max_results': 15,
        'sortBy': 'relevance',
        'sortOrder': 'descending'
    })
    url = f'http://export.arxiv.org/api/query?{params}'
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'PV-Calculator-Research/1.0'})
        with urllib.request.urlopen(req, timeout=60) as resp:
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
            if not pdf_url and arxiv_id:
                pdf_url = arxiv_id.replace('/abs/', '/pdf/') + '.pdf'
            
            cats = entry.find('arxiv:primary_category', ARXIV_NS)
            category = cats.get('term') if cats is not None else ''
            
            paper = {
                'title': title,
                'authors': authors[:5],  # limit authors
                'published': published,
                'arxiv_id': arxiv_id,
                'pdf_url': pdf_url,
                'category': category,
                'abstract': summary[:1500],
                'query_found': query,
            }
            all_papers[arxiv_id] = paper
    except Exception as e:
        print(f"  Error: {e}")
    
    if i < len(queries) - 1:
        print("  Sleeping 20s...")
        time.sleep(20)

print(f"\nTotal unique papers found: {len(all_papers)}")

with open('/home/paperclip/git/pv-calculator/research/arxiv_raw.json', 'w') as f:
    json.dump(list(all_papers.values()), f, indent=2)

print("Saved to research/arxiv_raw.json")
