export async function onRequest(context) {
  const response = await context.next();
  if (context.request.method !== 'GET') return response;

  const url = new URL(context.request.url);
  if (url.pathname !== '/companies/company-1/main.html') return response;

  const contentType = response.headers.get('content-type') || '';
  if (!contentType.toLowerCase().includes('text/html')) return response;

  const html = await response.text();
  const broken = "esc(x.status||'-')]))));";
  const canonical = "esc(x.status||'-')])));";
  const occurrences = html.split(broken).length - 1;

  const headers = new Headers(response.headers);
  headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
  headers.set('CDN-Cache-Control', 'no-store');
  headers.set('Pragma', 'no-cache');

  if (occurrences === 1) {
    headers.set('X-RAWAEA-HR-SHELL', 'repaired-stale-rw-hr-payroll');
    return new Response(html.replace(broken, canonical), {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  }

  if (occurrences > 1) {
    headers.set('X-RAWAEA-HR-SHELL', 'ambiguous-stale-rw-hr-payroll');
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