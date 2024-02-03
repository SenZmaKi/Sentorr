<script>
  import "./global.css"; // Import your global styles
  import { APP_NAME } from "../constants.js"; // Import your constants

  let featuredContent = [
    {
      title: "Featured Stream Title",
      image: "placeholder-image.jpg",
      description: "Description of the featured stream...",
      url: "stream-url",
    },
    // Add more featured content items as needed
  ];

  let categories = [
    {
      name: "Category Name",
      image: "category-image.jpg",
      url: "category-url",
    },
    // Add more categories as needed
  ];
</script>

<main>
  <header>
    <h1>APP_NAME</h1>
  </header>

  <section id="featured-content">
    <h2>Featured Content</h2>
    {#each featuredContent as { title, image, description, url }}
      <div class="stream-card">
        <img src={image} alt={title} />
        <h3>{title}</h3>
        <p>{description}</p>
        <a href={url}>Watch Now</a>
      </div>
    {/each}
  </section>

  <section id="categories">
    <h2>Explore Categories</h2>
    {#each categories as { name, image, url }}
      <div class="category">
        <h3>{name}</h3>
        <img src={image} alt={name} />
        <a href={url}>Explore</a>
      </div>
    {/each}
  </section>
</main>

<footer>
  <p>&copy; {new Date().getFullYear()} Your Streaming App</p>
</footer>

<style>
  /* Add your component-specific styles here */
</style>
