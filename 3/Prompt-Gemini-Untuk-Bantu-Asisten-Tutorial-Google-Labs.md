# 🧠 Panduan Mengerjakan Lab Google Cloud yang Hanya Memberikan *Hints* Menggunakan Prompt Gemini

> **Belajar lebih cerdas, bukan menebak-nebak. Manfaatkan Gemini sebagai mentor untuk membantu memahami petunjuk (hints) pada Google Cloud Skills Boost, tanpa menghilangkan proses belajar.**

![Google Cloud](https://img.shields.io/badge/Google%20Cloud-Skills%20Boost-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)
![Gemini](https://img.shields.io/badge/Gemini-AI-blue?style=for-the-badge)
![Hands-on Labs](https://img.shields.io/badge/Hands--on-Labs-success?style=for-the-badge)
![Learning](https://img.shields.io/badge/Learn-Smarter-orange?style=for-the-badge)

---

# 📢 Sebelum Memulai

Pastikan terlebih dahulu kamu telah bergabung sebagai anggota Guild agar memperoleh pendampingan selama mengikuti program Google Skills Arcade.

📖 **Undangan Guild KKGI @ Google Skills Arcade Fasilitator 2026**

https://github.com/Koperasi-KKGI/Guild-at-Google-Skills-Arcade-Fasilitator-2026/

Selain mendapatkan informasi terbaru, kamu juga dapat berdiskusi dengan fasilitator maupun peserta lain ketika menemui kendala selama mengerjakan lab.

---

# 🤔 Mengapa Banyak Peserta Kesulitan?

Jika kamu baru pertama kali mengikuti Google Cloud Skills Boost, kemungkinan besar kamu pernah menemukan kondisi seperti berikut.

Pada suatu task hanya terdapat tulisan seperti:

> **Create and schedule a discovery scan configuration to run daily for Cloud Storage**

Lalu di bawahnya hanya tersedia beberapa **Helpful Hint** tanpa penjelasan langkah demi langkah.

Bagi peserta yang sudah terbiasa menggunakan Google Cloud Console mungkin hal ini tidak menjadi masalah.

Namun bagi peserta baru, sering muncul pertanyaan seperti:

- Menu yang dimaksud ada di mana?
- Tombol apa yang harus diklik?
- Bagian mana yang harus diisi?
- Kenapa hasil saya berbeda?
- Apakah saya melewatkan sesuatu?

Google memang sengaja membuat sebagian lab hanya memberikan **petunjuk (hints)** agar peserta benar-benar belajar memahami produk Google Cloud, bukan sekadar mengikuti tutorial.

Di sinilah **Gemini** dapat menjadi asisten belajar yang sangat membantu.

---

# 💡 Gemini Bukan Untuk Mencontek

Sebelum melanjutkan, ada satu hal penting yang perlu dipahami.

Gunakan Gemini sebagai **asisten pembelajaran**, bukan untuk menyalin jawaban tanpa memahami prosesnya.

Tujuan utamanya adalah:

- membantu menerjemahkan hint menjadi langkah-langkah yang mudah dipahami,
- menjelaskan letak menu,
- menjelaskan fungsi setiap konfigurasi,
- membantu ketika dokumentasi resmi terlalu singkat.

Dengan cara ini kamu tetap memperoleh pengalaman belajar yang sesungguhnya.

---

# ✅ Persiapan Sebelum Membuka Gemini

Siapkan informasi yang tersedia pada lab.

Biasanya Google memberikan akun sementara seperti berikut.

```text
Username
student-01-5950e0be5421@qwiklabs.net

Username
student-01-d8c3f86845d2@qwiklabs.net

Project ID
qwiklabs-gcp-02-66e719510c9f
```

> **Catatan:** Gunakan akun dan Project ID yang diberikan pada lab milikmu sendiri. Contoh di atas hanya ilustrasi.

Informasi tersebut akan membantu Gemini memberikan instruksi yang lebih spesifik apabila diperlukan.

---

# 📋 Cara Membuat Prompt yang Baik

Kesalahan yang sering dilakukan peserta adalah hanya menuliskan:

> Tolong kerjakan lab ini.

Prompt seperti ini terlalu umum.

Gemini tidak mengetahui:

- lab apa yang sedang dikerjakan,
- task nomor berapa,
- tujuan task,
- hint yang diberikan,
- project yang digunakan.

Semakin lengkap informasi yang diberikan, semakin baik pula jawaban yang akan diperoleh.

---

# ⭐ Contoh Prompt yang Direkomendasikan

Salin dan sesuaikan prompt berikut.

````text
Saya sedang mengerjakan Google Cloud Skills Boost.

Tolong jangan hanya memberikan jawaban singkat.

Saya ingin kamu bertindak sebagai mentor Google Cloud.

Berikan langkah-langkah yang sangat rinci.

Gunakan bahasa Indonesia.

Jelaskan menu yang harus diklik satu per satu.

Jika ada konfigurasi yang harus diisi,
jelaskan alasan mengapa nilai tersebut dipilih.

Jika terdapat beberapa kemungkinan menu,
jelaskan perbedaannya.

Jangan melewati langkah sekecil apa pun.

Project ID saya:

qwiklabs-gcp-02-66e719510c9f

Task yang harus saya kerjakan adalah:

Create and schedule a discovery scan configuration to run daily for Cloud Storage

Berikut hint dari Google:

Property Value

Select scope Scan selected project

Managed schedules Edit Default schedule to specify Reprofile Daily for On a schedule and When inspect template changes

Select inspection template Create a new inspection template

Save data profile copies to BigQuery

Dataset ID

cs_discovery

Table ID

cs_data_profiles

Current Project

Location

Multi_region > us

Display Name

Cloud Storage Daily Discovery

Lab referensi:

https://www.skills.google/catalog_lab/31804

Tolong jelaskan langkah demi langkah sampai task selesai.
