#!/usr/bin/env python3
"""Search Semantic Scholar API for PV/solar related papers."""
import urllib.request
import urllib.parse
import json
import time

queries = [
    'photovoltaic self-consumption optimization residential',
    'PV battery dispatch strategy state of charge',
    'solar irradiance estimation rooftop residential',
    'inverter clipping photovoltaic power limitation',
    'PV system sizing algorithm simulation',
    'battery storage self-consumption solar residential',
    'solar yield estimation photovoltaic calculator',
    'microinverter photovoltaic performance simulation',
]

all_papers = {}
seen_ids = set()

for i, query in enumerate(queries):
    print(f"Query {i+1}/{len(queries)}: {query}")
    params = urllib.parse.urlencode({
        'query': query,
        'limit': 15,
        'fields': 'title,authors,year,externalIds,abstract,url,openAccessPdf,fieldsOfStudy,citationCount',
    })
    url = f'https://api.semanticscholar.org/graph/v1/paper/search?{params}'
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'PV-Calculator-Research/1.0'})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        
        results = data.get('data', [])
        print(f"  Got {len(results)} results")
        for p in results:
            pid = p.get('paperId', '')
            if pid in seen_ids or not pid:
                continue
            seen_ids.add(pid)
            
            ext_ids = p.get('externalIds', {}) or {}
            arxiv_id = ext_ids.get('ArXiv', None)
            doi = ext_ids.get('DOI', None)
            
            authors_list = []
            for a in (p.get('authors') or []):
                name = a.get('name', '')
                if name:
                    authors_list.append(name)
            
            oa_pdf = p.get('openAccessPdf') or {}
            pdf_url = oa_pdf.get('url') if oa_pdf else None
            if not pdf_url and arxiv_id:
                pdf_url = f"https://arxiv.org/pdf/{arxiv_id}.pdf"
            
            paper = {
                'title': p.get('title', 'N/A'),
                'authors': authors_list[:6],
                'year': p.get('year'),
                'arxiv_id': f"https://arxiv.org/abs/{arxiv_id}" if arxiv_id else None,
                'doi': doi,
                'abstract': (p.get('abstract') or 'N/A'),
                'pdf_url': pdf_url,
                'semantic_scholar_url': p.get('url'),
                'fieldsOfStudy': p.get('fieldsOfStudy'),
                'citationCount': p.get('citationCount'),
                'query_found': query,
            }
            all_papers[pid] = paper
    except Exception as e:
        print(f"  Error: {e}")
    
    if i < len(queries) - 1:
        time.sleep(3.5)  # Semantic Scholar allows ~1 req/sec

print(f"\nTotal unique papers from Semantic Scholar: {len(all_papers)}")

with open('/home/paperclip/git/pv-calculator/research/semanticscholar_raw.json', 'w') as f:
    json.dump(list(all_papers.values()), f, indent=2)

print("Saved to research/semanticscholar_raw.json")
