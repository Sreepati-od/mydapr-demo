using Dapr.Client;
using Dapr;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddDaprClient();

var app = builder.Build();

app.UseCloudEvents();
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


app.Run();

record ProductCreateRequest(string Name, decimal Price);
record ProductDto(Guid Id, string Name, decimal Price, DateTime CreatedUtc);
