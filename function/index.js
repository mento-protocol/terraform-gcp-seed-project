const https = require("https");

exports.sendDiscordNotification = (req, res) => {
  const discordWebhookUrl = process.env.DISCORD_WEBHOOK_URL;
  const incident = req.body.incident;

  if (!incident) {
    res.status(400).send("No incident data provided");
    return;
  }

  const message = {
    content: `Alert: ${incident.policy_name}`,
    embeds: [
      {
        title: incident.condition_name,
        description: incident.summary,
        color: incident.state === "open" ? 16711680 : 65280, // Red for open, green for closed
        fields: [
          {
            name: "State",
            value: incident.state,
            inline: true,
          },
          {
            name: "Started At",
            value: new Date(incident.started_at).toLocaleString(),
            inline: true,
          },
        ],
      },
    ],
  };

  const options = {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
  };

  const request = https.request(discordWebhookUrl, options, (response) => {
    let data = "";
    response.on("data", (chunk) => {
      data += chunk;
    });
    response.on("end", () => {
      res.status(200).send("Notification sent to Discord");
    });
  });

  request.on("error", (error) => {
    console.error("Error:", error);
    res.status(500).send("Error sending notification to Discord");
  });

  request.write(JSON.stringify(message));
  request.end();
};
