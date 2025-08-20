using Dapr;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

[ApiController]
public class OrderEventsController : ControllerBase
{
    private static readonly List<OrderDto> Orders = ProgramOrdersAccessor.Orders;
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true
    };

    [Topic("messagebus", "product.created")]
    [HttpPost("/product-created")] 
    public IActionResult OnProductCreated([FromBody] JsonElement cloudEvent)
    {
        try
        {
            Console.WriteLine($"[OrderEventsController] Received raw payload: {cloudEvent}");
            ProductCreatedEvent? product = null;
            if (cloudEvent.ValueKind == JsonValueKind.Object)
            {
                if (cloudEvent.TryGetProperty("data", out var dataElement))
                {
                    product = JsonSerializer.Deserialize<ProductCreatedEvent>(dataElement.GetRawText(), JsonOpts);
                }
                else
                {
                    // Attempt to deserialize root as the product (Dapr .NET SDK publishes camelCase by default)
                    product = JsonSerializer.Deserialize<ProductCreatedEvent>(cloudEvent.GetRawText(), JsonOpts);
                }
            }
            if (product != null)
            {
                var autoOrder = new OrderDto(Guid.NewGuid(), product.Id, DateTime.UtcNow);
                Orders.Add(autoOrder);
                Console.WriteLine($"[OrderEventsController] Created order {autoOrder.Id} from product {product.Id}");
            }
            else
            {
                Console.WriteLine("[OrderEventsController] Unable to deserialize product created event.");
            }
            return Ok();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[OrderEventsController] Error processing event: {ex}");
            return StatusCode(500);
        }
    }
}

public static class ProgramOrdersAccessor
{
    // Simple holder for in-memory state shared with Program
    public static List<OrderDto> Orders { get; } = new();
}
