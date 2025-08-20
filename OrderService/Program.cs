using Dapr;
using Dapr.Client;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddDaprClient();
builder.Services.AddControllers().AddDapr();
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
});

var app = builder.Build();

app.UseCloudEvents();
app.MapSubscribeHandler();

var orders = ProgramOrdersAccessor.Orders;

app.MapPost("/orders", (OrderCreateRequest request) =>
{
    var order = new OrderDto(Guid.NewGuid(), request.ProductId, DateTime.UtcNow);
    orders.Add(order);
    return Results.Created($"/orders/{order.Id}", order);
});

app.MapGet("/orders", () => orders);


app.MapControllers();

app.Run();

public record OrderCreateRequest(Guid ProductId);
public record OrderDto(Guid Id, Guid ProductId, DateTime CreatedUtc);
public class ProductCreatedEvent
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public DateTime CreatedUtc { get; set; }
}
