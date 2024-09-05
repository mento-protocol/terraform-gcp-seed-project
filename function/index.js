const https = require("https");

/**
 * Type guard to check if the provided fields are valid.
 * @param {any} fields - The fields to check.
 * @returns {boolean} - True if fields are valid, false otherwise.
 */
function isValidFields(fields) {
  if (!Array.isArray(fields)) {
    return false;
  }

  return fields.every((field) => {
    if (typeof field !== "object" || field === null) {
      return false;
    }

    if (typeof field.name !== "string" || typeof field.value !== "string") {
      return false;
    }

    if ("inline" in field && typeof field.inline !== "boolean") {
      return false;
    }

    return true;
  });
}

/**
 * Type guard to validate a Discord webhook URL.
 * @param {string} url - The URL to validate.
 * @returns {boolean} - True if the URL is valid, false otherwise.
 */
function isValidDiscordWebhookUrl(url) {
  const regex = /^https:\/\/discord\.com\/api\/webhooks\/\d+\/[\w-]+$/;
  return regex.test(url);
}

/**
 * A function for sending Discord notifications for use in a Google Cloud message channel.
 *
 * @param {Object} req - The request object from the Cloud Function trigger.
 * @param {Object} req.body - The body of the request.
 * @param {Object} req.body.content - The content of the notification.
 * @param {string} req.body.content.description - The description of the notification.
 * @param {string} req.body.content.contentTitle - The title of the content.
 * @param {string} req.body.content.title - The main title of the notification.
 * @param {('GOOD'|'CRITICAL'|'WARNING'|'INFO')} req.body.content.type - The type of the notification, which determines its color.
 * @param {Array<Object>} req.body.content.fields - An array of field objects for the Discord embed.
 * @param {string} req.body.content.fields[].name - The name of the field.
 * @param {string} req.body.content.fields[].value - The value of the field.
 * @param {boolean} [req.body.content.fields[].inline] - Whether the field should be displayed inline.
 * @param {Object} res - The response object to send the result of the function.
 * @returns {void}
 */
exports.sendDiscordNotification = (req, res) => {
  const { description, contentTitle, title, type, fields, discordWebhookUrl } =
    req.body.content;

  if (!req.body.content) {
    res.status(400).send("No message data provided");
    return;
  }

  if (!isValidDiscordWebhookUrl(discordWebhookUrl)) {
    res.status(400).send("Invalid Discord webhook URL");
    return;
  }

  if (!isValidFields(fields)) {
    res.status(400).send("Invalid fields provided");
    return;
  }

  if (typeof description !== "string" || description.trim() === "") {
    res.status(400).send("Invalid or missing description");
    return;
  }

  if (typeof contentTitle !== "string" || contentTitle.trim() === "") {
    res.status(400).send("Invalid or missing contentTitle");
    return;
  }

  if (typeof title !== "string" || title.trim() === "") {
    res.status(400).send("Invalid or missing title");
    return;
  }

  if (
    typeof type !== "string" ||
    !["GOOD", "CRITICAL", "WARNING", "INFO"].includes(type)
  ) {
    res
      .status(400)
      .send(
        "Invalid or missing type. Must be 'GOOD', 'CRITICAL', 'WARNING', 'INFO'",
      );
    return;
  }

  let color = 65280; // Good Green

  if (type === "CRITICAL") {
    color = 16711680; // Critical Red
  } else if (type === "WARNING") {
    color = 16776960; // Warning Orange
  } else if (type === "INFO") {
    color = 13209; // Info Blue
  }

  const message = {
    content: contentTitle,
    embeds: [
      {
        title: title,
        description: description,
        color: color,
        fields: fields,
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
