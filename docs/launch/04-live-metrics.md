# Live numbers from pub.dev and GitHub

**Decision (7 Nov 2026):** numbers on the website are pulled live, never typed in. This removes the mismatches listed in [01-website-audit.md](01-website-audit.md).

## What to show

| Number | Source | Where on the site |
|---|---|---|
| Latest version | pub.dev package API | Case study header, install snippet, open-source card, JSON-LD `softwareVersion`, docs version label |
| Pub points (x / 160) | pub.dev score API | Case study, open-source card |
| Likes | pub.dev score API | Case study, open-source card |
| Downloads (last 30 days) | pub.dev score API | Case study, open-source card |
| GitHub stars | GitHub REST API | Open-source page only |

Don't show a rating: pub.dev has none.

## Endpoints

Fetch these on the server (in a Next.js server component or route handler), not from the browser. That avoids CORS issues and rate limits, and it keeps the numbers in the HTML for search engines.

```text
GET https://pub.dev/api/packages/flutter_mfa
    → latest.version, latest.published

GET https://pub.dev/api/packages/flutter_mfa/score
    → grantedPoints, maxPoints, likeCount, downloadCount30Days

GET https://api.github.com/repos/Breaktroughf1/flutter_mfa
    → stargazers_count, forks_count
```

Before the first publish, both pub.dev URLs return **404**. The page must handle that (see below). Check the response field names against the live API on publish day, and keep the parsing defensive (a missing field means "hide that number").

## Example (Next.js App Router)

```ts
// lib/flutter-mfa-stats.ts
type Stats = {
  version?: string;
  points?: { granted: number; max: number };
  likes?: number;
  downloads30d?: number;
  stars?: number;
};

// Never throws: a 404 (not yet published), an HTTP error, a network
// failure or bad JSON all mean "no data", so each number hides on its own.
async function json(url: string): Promise<any | undefined> {
  try {
    const res = await fetch(url, {
      headers: { Accept: 'application/json' },
      next: { revalidate: 3600 }, // refresh at most hourly
    });
    return res.ok ? await res.json() : undefined;
  } catch {
    return undefined;
  }
}

export async function flutterMfaStats(): Promise<Stats> {
  const [pkg, score, repo] = await Promise.all([
    json('https://pub.dev/api/packages/flutter_mfa'),
    json('https://pub.dev/api/packages/flutter_mfa/score'),
    json('https://api.github.com/repos/Breaktroughf1/flutter_mfa'),
  ]);
  return {
    version: pkg?.latest?.version,
    points:
      typeof score?.grantedPoints === 'number'
        ? { granted: score.grantedPoints, max: score.maxPoints }
        : undefined,
    likes: score?.likeCount,
    downloads30d: score?.downloadCount30Days,
    stars: repo?.stargazers_count,
  };
}
```

## Rules

- **Missing means hidden.** If a number is undefined (not yet published, API down, network error), leave that badge out. Never fall back to a typed number. Each endpoint fails on its own: one outage must never stop the page rendering.
- **Revalidate hourly.** pub.dev updates scores after each publish and downloads daily. Hourly is plenty.
- **One fetch, many places.** Use the same `flutterMfaStats()` for the case study, the open-source page, the docs version label and the JSON-LD.
- **Other packages.** For the open-source page, the same calls work for `flutter_mfa_core`, `flutter_mfa_ui` and `flutter_mfa_qr`. Show the plugin (`flutter_mfa`) as the headline package.
- **Badges as a fallback.** If server fetching is not possible, shields.io badges render live images: `https://img.shields.io/pub/v/flutter_mfa`, `https://img.shields.io/pub/points/flutter_mfa`, `https://img.shields.io/pub/likes/flutter_mfa`. They are not in the HTML for search engines, so prefer the fetch.
