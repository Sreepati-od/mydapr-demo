using Dapr.Client;
using Dapr;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddDaprClient();
// CORS (allow webclient)
var allowedOrigins = Environment.GetEnvironmentVariable("ALLOWED_ORIGINS")
    ?? "*"; // demo default
builder.Services.AddCors(options =>
{
    options.AddPolicy("web", policy =>
    {
        if (allowedOrigins == "*")
            policy.AllowAnyOrigin();
        else
            policy.WithOrigins(allowedOrigins.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        policy.AllowAnyHeader().AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseCloudEvents();
app.UseCors("web");
app.MapMethods("/products", new[]{"OPTIONS"}, () => Results.Ok())
    .WithName("ProductsPreflight");
app.MapSubscribeHandler();

// Simple in-memory list of products
var products = new List<ProductDto>();

// Create product and publish event
app.MapPost("/products", async (ProductCreateRequest request, DaprClient daprClient) =>
{
    var product = new ProductDto(Guid.NewGuid(), request.Name, request.Price, DateTime.UtcNow);
    products.Add(product);
    // Publish event to Dapr pubsub component
    await daprClient.PublishEventAsync("messagebus", "product.created", product);
    Console.WriteLine($"[ProductService] Published product.created for {product.Id}");
    return Results.Created($"/products/{product.Id}", product);
});

app.MapGet("/products", () => products);

// Root info/health
app.MapGet("/", () => Results.Ok(new { service="productservice", routes=new[]{"/products"}, count=products.Count }));


app.Run();

record ProductCreateRequest(string Name, decimal Price);
record ProductDto(Guid Id, string Name, decimal Price, DateTime CreatedUtc);
