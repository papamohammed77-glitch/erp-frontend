export async function onRequest(context) {
  const response = await context.next();
  if (context.request.method !== 'GET') return response;

  const url = new URL(context.request.url);
  if (url.pathname !== '/companies/company-1/main.html') return response;

  const contentType = response.headers.get('content-type') || '';
  if (!contentType.toLowerCase().includes('text/html')) return response;

  let html = await response.text();
  let repaired = false;
  let ambiguous = false;

  const brokenPayroll = "esc(x.status||'-')]))));";
  const canonicalPayroll = "esc(x.status||'-')])));";
  const payrollOccurrences = html.split(brokenPayroll).length - 1;

  if (payrollOccurrences === 1) {
    html = html.replace(brokenPayroll, canonicalPayroll);
    repaired = true;
  } else if (payrollOccurrences > 1) {
    ambiguous = true;
  }

  const brokenTerminal = /(\r?\n)\s*window\.RW_HR=\{render:render,reload:render,openEmployee360:open360\};\s*\r?\n\s*\}\(\)\);\s*\r?\n\s*window\.RW_HR = RW_HR;/g;
  const terminalMatches = html.match(brokenTerminal) || [];

  if (terminalMatches.length === 1) {
    html = html.replace(
      brokenTerminal,
      '$1  window.RW_HR={render:render,reload:render,openEmployee360:open360};\n  window.RW_HR = RW_HR;'
    );
    repaired = true;
  } else if (terminalMatches.length > 1) {
    ambiguous = true;
  }

  const headers = new Headers(response.headers);
  headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  headers.set('CDN-Cache-Control', 'no-store');
  headers.set('Pragma', 'no-cache');

  if (ambiguous) {
    headers.set('X-RAWAEA-HR-SHELL', 'ambiguous-rw-hr-syntax');
    return new Response(html, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  }

  if (repaired) {
    headers.set('X-RAWAEA-HR-SHELL', 'repaired-rw-hr-syntax');
    return new Response(html, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  }

  headers.set('X-RAWAEA-HR-SHELL', 'canonical');
  return new Response(html, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}