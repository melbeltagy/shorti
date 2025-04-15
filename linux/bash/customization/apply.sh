# Define the loop to be added
loop='for file in ~/lolo-koki/linux/bash/customization/*.bashrc; do
  source "$file"
done'

# Check if the loop already exists in .bashrc
if ! grep -qF "$loop" ~/.bashrc; then
  # Append the loop to .bashrc
  echo -e "\n$loop" >> ~/.bashrc
fi
