# Blogger Pagination

Antinna Engine utilizes the Blogger Feed API for efficient data loading.

## Dynamic Loading

The `BloggerDataService` provides a `fetchFeedData` method that supports Blogger's standard pagination parameters:
- `max-results`: Number of posts to fetch per request.
- `start-index`: The offset for the request.

## Load More Posts

The engine exposes a global function `loadMorePosts()` to support "Infinite Scroll" or "Load More" UI patterns.

### How to use in your XML template:
1.  Add a button to your template:
    ```html
    <button id="load-more-btn" onclick="AntinnaEngine.loadMorePosts()">Load More</button>
    ```
2.  The engine will automatically:
    *   Increment the start index.
    *   Fetch the next set of posts.
    *   Extract Schema data from each post.
    *   Append new Product/Service cards to the `#app-grid` container.
    *   Hide the button if no more posts are available.

## Performance
By using pagination, the engine ensures that the initial page load is fast, while still allowing customers to browse your entire catalog of products and services.
